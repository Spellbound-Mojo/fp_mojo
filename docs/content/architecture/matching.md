# Algebraic data and matching

Algebraic data types describe a value through its constructors. Inductive types
add recursive fields, so constructors can build expressions, lists or trees
from smaller values. In FP Mojo, you declare those constructors as structs and
write match clauses to handle them.

The compiler checks that the clauses are exhaustive and their types agree.
For recursive values, the matching engine uses an explicit stack and follows
only children or `Next` values of smaller height. The traversal therefore
terminates on finite data without depending on native stack depth. Clauses
themselves are ordinary Mojo functions; the guarantees below distinguish
their behavior from the engine's traversal.

The [data and matching](../tutorial/matching.md) and
[recursive data](../tutorial/recursion.md) tutorials show complete programs;
the schematic forms below use the names of `docs/examples/expression.mojo`.

## Declaring data

A data type lists its constructors. Each constructor is an ordinary
`@fieldwise_init` struct; a field that holds a sub-value of the same type has
the type parameter `R`:

```text
struct Num(Copyable):                  var value: Int
struct Add[R: Value](Movable):         var left: R;  var right: R
struct If[C: Value, B: Value](Movable): var cond: C;  var then: B;  var other: B

struct Expr(Data):
    comptime Layer[R: Value] = Cases[Num, Add[R], If[R, R]]
```

- `Value` is `Movable & Deinitable`.
- `Layer[R]` is the type's constructors with every recursive position filled by
  `R`. A recursive position is a field of type `R`, `List[R]` or `Optional[R]`;
  any other use of `R` in a field is a compile error.
- A constructor may take several type parameters, as `If` does, so that a clause
  can treat its fields differently. The declaration passes `R` to each.
- Constructor names are distinct within a type. The same declaration describes
  a non-recursive sum type when none of its constructors has a recursive field.

## Values

`Node[F]` is a value of data type `F`: one constructor whose recursive fields
hold `Node[F]` values. A constructor converts to a `Node` implicitly:

```text
comptime E = Node[Expr]
var x: E = Num(2)
var e: E = Add(x, E(Add(x, x)))        # x is shared
```

- **Immutable and shared.** Copying a `Node` shares it, in constant time; nothing
  can change a node after construction.
- **Finite and acyclic by construction.** A node can only refer to nodes that
  already exist, so every node and everything it reaches form a finite directed
  acyclic graph. Shared sub-values make it a graph rather than a tree.
- **Inspection.** `node.isa[Num]()`, `node[Num]` (a reference; a wrong
  constructor aborts) and `node == Num(0)` for constructors that are
  `Equatable`.
- **Height.** Each node stores its height, the longest path to a leaf, computed
  once at construction.
- **Destruction** runs in a loop, so dropping a value a million levels deep does
  not recurse.
- **Cost.** One heap allocation per node and an atomic reference count, as
  `ArcPointer`.

## Values stored in place

`Choice[F]` is a value of a data type with no recursive field, stored where it
is declared in a native `Variant`:

```text
struct Shape(Data):
    comptime Layer[R: Value] = Cases[Circle, Rect]

var s: Choice[Shape] = Circle(1.0)
```

- **Ownership.** Copying a `Choice` copies its constructor; it is
  `Copyable`, or `ImplicitlyCopyable`, only when every constructor is. A
  constructor that is only `Movable` can be stored, and `unwrap[C]()` moves it
  out.
- **Storage.** A `Choice` adds no allocation or reference count beyond the
  constructor stored in its `Variant`.
- **Inspection.** `isa[C]()`, `s[C]` and `s == C(...)`, as for a `Node`.
- **Not recursive.** A field of type `R`, `List[R]` or `Optional[R]` is a
  compile error naming the field: a recursive value is a `Node`.

`Result[T, E]` (`Ok[T]` or `Err[E]`) and `ControlFlow[B, C]` (`Break[B]` or
`Continue[C]`) are stored the same way. A `Node` of a non-recursive type is
still valid, when sharing is wanted.

## Matching

```text
fp.match(e,
    lambda (n: Num) -> Int: n.value,
    lambda (a: Add[Int]) -> Int: a.left + a.right,
    lambda (c: If[Int, E]) -> Next[E]: Next(c.then if c.cond != 0 else c.other))
```

`fp.match(subject, clauses...)` takes one to sixteen clauses. A clause is a
plain function or a lambda without captures. Its parameter type says which
constructor it handles and how each field arrives:

| Clause field type | The field arrives |
|---|---|
| The constructor's own field type | As it is: copied, or shared for a `Node` |
| `R` in place of a recursive field | Evaluated first: the result of matching that child with the same clauses |
| `List[R]`, `Optional[R]` in place of `List[Node]`, `Optional[Node]` | Each element evaluated first |

A parameter of the whole type, `lambda (e: E) -> ...`, is a catch-all that
accepts any constructor as it is. A clause returns the result type, or
`Next(node)`: the result of this value is the result of matching `node` instead.

**Guards.** `fp.when[guard, clause]` is a clause that applies only when `guard`
returns true for the same argument; otherwise the next clause for that
constructor is tried. Literal and nested patterns are guards and nested
matches: `fp.when[lambda (a: Add[E]) -> Bool: a.left == Num(0), ...]`, or an
`fp.match` on a field inside a clause. Fields a declining clause had evaluated
are kept for the next one, so a field is evaluated at most once per value.

**Selection.** For a value with constructor `C`, the clauses for `C` and the
catch-alls are tried in the order written; the first that applies is used.
Clauses for different constructors may come in any order.

**Subjects that are not Nodes.** The subject may also be a value stored in
place (`Choice`, `Result`, `ControlFlow`), whose clauses take a constructor or
the whole type, or a standard `Optional[T]`, whose clauses take `T` for a present
value, `NoneType` for an absent one, or `Optional[T]`. A clause receives a
reference to the stored constructor or value, so nothing is copied, and guards,
context, errors and admission work as for a `Node`. There is nothing to
evaluate first and nothing to continue with, so evaluated fields and `Next` are
for `Node` subjects only. Any other value can be a subject too, matched by
clauses that take its type.

**Context.** `fp.match(subject, clauses..., context=value)` passes the same
borrowed value to every clause as a second parameter, for data a clause needs
but the subject does not hold, such as an environment. Clauses do not capture
state, so a match is a deterministic function of its subject and context.

**Errors.** A clause may raise. Every clause raises `Never` or one common error
type, which the match raises unchanged. A raise stops the match immediately; no
later clause or sibling runs, and pending results are released.

## Rewriting

`fp.rewrite(node, clauses...)` transforms a value bottom-up. Clauses handle only
the constructors that change and return the new node; recursive fields arrive
already rewritten. Every other node is rebuilt from its rewritten children, and
a node whose children are unchanged is reused, so sharing is preserved:

```text
fp.rewrite(e,
    fp.when[lambda (a: Add[E]) -> Bool: a.left == Num(0),
            lambda (a: Add[E]) -> E: a.right])
```

A rewrite is a single pass; it is not repeated until nothing changes. A rewrite
clause takes a constructor, never the whole type.

## Several subjects

`fp.match((a, b), clauses...)` matches two or three values together. Each clause
takes one parameter per component, as for a single subject: a constructor (for a
`Node`, as stored) or the whole type, the type of a present `Optional` value or
`NoneType`, or the component's own type. The first clause whose parameters all
apply and that does not decline is used, and every combination of cases must be
covered. Fields of several subjects arrive as they are; evaluated fields and
`Next` are not available with several subjects. The tuple holds its
components: a `Node` is shared into it, and a value that is not implicitly
copyable is copied with `.copy()` or moved with `^`.

## Admission

The compiler checks the following rules before a match can run. Diagnostics
identify a constructor or a clause's position, counting from 0:

- Every constructor has a clause that cannot decline, or a catch-all does; with
  several subjects, every combination of constructors does.
- A clause that can never be selected, because earlier clauses that cannot
  decline cover everything it applies to, is an error.
- A clause's parameter is a constructor of the subject's type, the whole type, or
  a context, `Optional` case or component type as above; each field follows the
  table above.
- Every clause produces the same result type, apart from `Next`, and at least
  one produces a value.
- Every clause raises `Never` or the common error type.
- With a context, every clause's second parameter is the context's type.
- Fields that arrive as they are and are not `Node`s must be `Copyable`; a
  guarded clause that evaluates fields needs a `Copyable` result.

## Guarantees and their sources

| Guarantee | Source |
|---|---|
| Exhaustive and well typed | The admission rules |
| Terminates on finite data | Evaluated fields are strict sub-components of the matched value, and `Next` must continue with a value of smaller height (checked once per step; a violation aborts). Values are finite and acyclic, so every chain of steps is finite. |
| No stack limit | Pending values are kept on an explicit stack in one loop; nothing recurses natively |
| Shared sub-values once | When the result type is `Copyable`, a node referenced more than once is evaluated once per match and its result copied to every use; otherwise once per occurrence |
| Only demanded work | A field is evaluated only if a clause that is tried asks for it; the branch an `If` does not take is never evaluated |

The guarantees cover the matching itself. A clause is an ordinary function: its
own loops, or another match it starts on a different value, are ordinary code.

## Execution

A match runs one loop over a stack of pending values. At compile time, the
engine builds a plan for each constructor: which clauses to try, which fields
each clause needs evaluated, and where their results belong. Each pending value
occupies a 32-byte frame containing the value, its current step in the plan,
and the position where its children's results begin on the value stack.

- The frame on top runs its steps until it needs a child. The child is started
  at once: if it completes in one step, as a leaf does, its result is pushed and
  no frame is made; otherwise its frame is pushed and the loop continues with it.
- When a clause runs, the results of the fields it takes are popped from the
  value stack into its argument; the other fields are copied from the value.
  The result is pushed for the parent, or, for `Next`, the frame continues with
  the new value.
- A declining `when` clause receives copies, so the results stay for the next
  clause, which evaluates only the fields not evaluated yet.

A subject that is not a `Node`, and a tuple of subjects, needs no loop: the
clauses are tried in order against each component's case, and the first that
applies, and does not decline, is called with references into the subjects.

Constructor dispatch, field movement and argument construction are generated
from the clause types; no pattern is interpreted at run time. The cost per value
is one dispatch, the evaluated fields, the clause call and, when the result type
is `Copyable`, one reference-count read to detect sharing.

With clauses that do almost nothing, on an x86-64 host
(`tests/benchmarks/bench_match.mojo`):

| Value | Hand-written recursion | Hand-written explicit-stack loop | `fp.match` |
|---|---|---|---|
| Balanced tree, 9,556 values | 1× (about 1.9 ns per value) | about 2.4× | about 3× |
| Chain 10,000 deep | 1× | about 0.9× | about 1.2× |

A loop keeps the state of every pending value in memory, where recursion keeps
it in registers and return addresses; on a shallow value that costs the loop a
factor of two, and on a deep one it costs nothing, because deep recursion is no
better at keeping its frames in cache. `fp.rewrite`, which allocates the values
it rebuilds, is within a few percent of the hand-written version. The trip count
of the loop plays no part: recursion does not know the depth in advance either.

## Compile time

The clause forms are one generated overload per clause count and form (see
`scripts/generate_plain_overloads.py`): Mojo 1.1 reads a plain function's
signature only at a parameter of its function type. The generated signatures
spell the result and error types flat over the clause types, because deriving
them from the clause list takes compile time exponential in the number of
clauses ([native boundaries](native-boundaries.md#generic-code)).
Importing `fp.matching` adds about a second to a cold build, and a program that
matches and rewrites an expression type builds in about 8 seconds at O3.

## Limits

- Sixteen clauses per match and three subjects.
- Clauses do not capture; use `context=` or a component of a subject tuple.
- Recursion over several subjects, matches that return references into the
  subject, and values computed on demand are not provided.
- A match borrows; it never consumes its subject. Consuming access belongs to
  the types: `Choice.unwrap`, `Result.fold_owned`, `Optional.take`.
- A native `Variant` is not a subject: a generic function cannot name its
  alternatives. Declare the type with `Data` and store it in a `Choice`.
