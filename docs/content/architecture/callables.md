# Callables and invocation

`fp.callables` defines the invocation protocols shared by pipelines, folds,
Result transformations and other higher-order operations. A protocol specifies
the callable's arguments, result, error type and receiver access, so consumers
can use the same invocation rules.

Match clauses use native thin function signatures directly. They accept plain
functions and lambdas without captures; see
[algebraic data and matching](matching.md).

## Callers of two kinds

A higher-order function receives user code in one of two forms:

| Form | Examples | How it is called |
|---|---|---|
| **Native function or closure** | `def f(x: Int) -> Int`, a capturing `def` | Directly, through a function-typed parameter of the entry point |
| **Library callable value** | `Partial`, `Composition`, `Flipped`, `NativeUnary`, user structs | Through a fixed-arity protocol (`Unary`, `Binary`, `Thunk`) or `BorrowCallable` |

A native function with keyword or default
parameters is used through a closure that spells the call.

## Three independent dimensions

Receiver access, argument conventions and result ownership are independent:

- **Receiver access.** Shared (the callable is read), exclusive (mutated in
  place) or consuming (called once and destroyed). Owning captured state does
  not make a callable single-use, and shared access is not a purity guarantee:
  a native closure can have effects through its captures.
- **Argument conventions.** Each argument is read, mutable or owned on its own.
  A shared callable may consume its arguments; a consuming callable may borrow
  them. No automatic copy makes an invalid combination compile.
- **Result.** An owned value, or an explicitly origin-bound reference. The native
  error channel stays separate from any `Result` value that is returned.

An algorithm requires only the receiver access it actually uses. A repeating
algorithm keeps one receiver for its whole run and never copies it per call, so
a consuming-only callable is rejected at compile time wherever a callback runs
more than once.

## Fixed-arity protocols

`UnaryContract`, `BinaryContract` and `ThunkContract` fix the argument, result
and error types on the callable itself. Each receiver mode is a separate trait:

| Arity | Shared | Exclusive | Consuming |
|---|---|---|---|
| one owned argument | `Unary.call` | `MutableUnary.call_mut` | `OnceUnary.call_once` |
| two owned arguments | `Binary.call` | `MutableBinary.call_mut` | `OnceBinary.call_once` |
| no argument | `Thunk.call` | `MutableThunk.call_mut` | `OnceThunk.call_once` |

A type implements only the modes it supports. Two free functions choose the mode:

- `call_once(f, ...)` calls any mode once and prefers the consuming one.
- `call_repeated(f, ...)` calls a callback that stays usable and prefers
  exclusive access. Generic code asserts `RepeatableUnary[F]`,
  `RepeatableBinary[F]` or `RepeatableThunk[F]` first, which is how a
  consuming-only callback is rejected before anything runs.

`as_unary(f)` moves a native function or closure into a `NativeUnary`, a `Unary`. `Partial`
implements `Thunk`, `Unary` or `Binary` when zero, one or two arguments remain;
`Composition` has the arity of its first-applied stage; `Flipped` is a `Binary`.
At O3 a call through any of these compiles to the same instructions as calling
the function directly.

The types live on the callable, so an algebra instance, an effect or a
composition computes its result type from the callback's `Out` alias without any
binding plan. Deriving types through per-call metadata instead is what made
programs take minutes to compile (see
[algebra and effects](algebra.md#why-the-core-is-shaped-this-way)).

## Native functions and closures

Mojo 1.1 records a native function's signature only when the value passes
through a parameter of that exact function type (`F: def(A) -> R`); a plain
generic `F` loses it. Each entry point that accepts closures therefore has one
overload per supported arity. A non-raising closure also does not match
`def(A) raises E -> R` with `E` inferred, so non-raising and raising closures have
separate overloads, and a raising callback keeps its exact error type.

Plain functions (no captures) convert to further signature shapes at a call
site, which the library uses where closures cannot reach:

- `partial` and `flip` accept plain functions of any arity through a read
  argument pack, because each call site forwards the pack unchanged.
- `pipe`, `flow` and `compose` accept two to eight plain functions through one
  overload per stage count, each stage spelled as a thin signature whose error
  is inferred (`Never` for a non-raising function). A variadic pack keeps a plain
  function's type but not its signature, so a stage's result could not be
  inferred from it. Each function is stored as a `_ThinFunction`, a `Thunk`,
  `Unary` or `Binary` value, and the chain goes through the ordinary planner.
- Match clauses are plain functions and lambdas without captures, through one
  generated overload per clause count; each clause's signature is read at a
  parameter of its own function type.

## Borrowed calls

`BorrowCallable` and `BorrowOnceCallable` are the fixed-metadata forms for read
access: `Payload`, `Result` and `Failure` are exact native types shared through
`BorrowCallContract`. `invoke_borrowed` calls a `BorrowCallable` with a borrowed
payload; iterator predicates, `while_loop` predicates and Result folds use this
route. The library never asserts two origins equal or rebinds a result to a
different origin to make a call compile.

## How consumers use the call boundary

| Consumer | Route and receiver |
|---|---|
| `pipe`, `flow`, `compose` | Plain functions stored as thin functions, closures promoted with `as_unary`, and `Thunk`/`Unary`/`Binary` values; the planner infers each stage's types |
| `piped(...).then` | One native function, closure or `Unary` value per call, inferred at that call |
| `flip` | A `Binary` value (receiver modes kept) or a plain function through a read pack |
| `partial` | A plain function stored directly; the result implements `Thunk`/`Unary`/`Binary` |
| `map`, `filter_map`, `flat_map`, `scan_left`, folds, reductions | Native callbacks or shared-receiver `Unary`/`Binary`; one receiver for the whole run |
| `filter`, `find`, `any`, `all` | Native predicates or `BorrowCallable`; candidates are borrowed |
| `attempt`, `attempt_once` | Native calls or a `OnceThunk`, then the Result bridge in `fp.data` |
| Result methods and folds | Native, fixed-arity or borrowed callbacks, called on the stored case |
| `fp.match`, `fp.rewrite`, `fp.when` | Plain functions and lambdas without captures, called through their native thin function type |
| `while_loop`, `fori_loop`, `scan` | Native callbacks, shared-receiver `Unary`/`Binary`, `BorrowCallable` predicates |
| `fp.algebra`, `fp.effects` | Fixed arity with `call_once` and `call_repeated`; native callbacks enter `map`, `flat_map` and `traverse` as a borrowed `_NativeUnaryRef` (held by a deferred computation until it runs) and `modify`, `censor` and `local` as a moved `NativeUnary` |

Domain algorithms stay with their owners: matching keeps clause selection and
its loop; iteration keeps its loops and state machines; `fp.data` owns the
conversion from a raised error to a `Result`. `fp.callables` adds no runtime
registry, dynamic dictionary, lifetime system, raw pack layout or origin
conversion.
