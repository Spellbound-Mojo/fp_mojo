# 6. Inductive data types

An inductive data type builds finite values from its constructors. An
expression, for example, can be a number or an addition of two expressions.
Declare recursive fields with the parameter `R` and store values in `Node`.

`fp.match` supports structural recursion over these values. Each clause chooses
whether to receive a recursive field as stored or as the result of matching
that child. Evaluation uses an explicit stack, so matching a value a million
levels deep does not overflow the native stack.

## Evaluate, render and simplify an expression

<!-- example: docs/examples/expression.mojo -->

`x` is `Add(Mul(1, 6), Add(4, 0))`. `render(x)` gives `(1 * 6 + (4 + 0))`, and
`evaluate(x)` gives `10`. `simplify` removes the multiplication by one and the
addition of zero, so the simplified value renders as `(6 + 4)` and still
evaluates to `10`.

- **Declare recursive fields with `R`.** `Add[R]` has two fields of type `R`.
  In `Expr` the layer passes `R` on, so a stored `Add` holds two `Node[Expr]`
  values. A constructor such as `If[C, B]` may take more than one parameter, so
  that a clause can treat the condition differently from the branches; the
  layer passes `R` to each.
- **Evaluate a child.** The clause parameter `Add[Int]` asks for both
  fields as the result type: they arrive as the results of matching the two
  children with the same clauses. `render` asks for `Add[String]` and gets the
  rendered children.
- **Keep a child unevaluated.** `If[Int, E]` asks for the condition evaluated
  and the branches as stored. The clause returns `Next(...)`: the result of this
  value is the result of matching the chosen branch instead. The other branch
  is never evaluated, so `If(zero, big, 7)` returns `7` without evaluating
  `big`, a product of 2^40 ones.
- **Rewrite bottom-up.** `fp.rewrite` transforms a value from the leaves up.
  Its clauses take the constructors that change, with recursive fields already
  rewritten, and return the new value. Every other value is rebuilt from its
  rewritten children, and a value whose children did not change is reused. A
  rewrite is one pass.
- **Share values.** `Node` values are immutable, and copying one shares it, so
  `Add(shared, shared)` refers to one value twice. After 61 doublings of
  `Num(2)`, `evaluate(shared)` returns `4611686018427387904`, evaluating each
  shared value once per match.
- **Match deeply nested values.** The match keeps pending values on an explicit
  stack and releases values in a loop. `deep` nests a million `Add` values, and
  `evaluate(deep)` returns `1000000` without a million native calls.

## Lists and optional children

A recursive field may also be `List[R]` or `Optional[R]`:

<!-- example: docs/examples/file_tree.mojo -->

`Folder[Int]` receives the sizes of all its entries, and `Shortcut[Int]` the
size of its target when it has one. `home` holds `notes.txt` (120), `photos`
(5000), a shortcut to `photos` (5000) and a shortcut with no target (0), so
`total_size(home)` returns `10120`. `listing` takes `Shortcut[T]`, the field as
stored, so it prints `latest@` without following the shortcut.

## Why every match ends

A `Node` can refer only to values that already exist, and it never changes, so
every value is a finite acyclic graph. Structural recursion evaluates children
of the current value; `Next` must continue with a value of smaller height.
These rules make the matching traversal terminate. A clause's own loops or
additional matches remain ordinary Mojo code. See
[guarantees and their sources](../architecture/matching.md#guarantees-and-their-sources)
for the termination argument and the runtime check on `Next`.

The next chapter combines these pieces in a
[configuration processor](application.md).
