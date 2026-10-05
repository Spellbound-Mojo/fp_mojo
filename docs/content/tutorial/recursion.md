# 6. Recursive data

A recursive data type has constructors whose fields hold values of the same
type. You mark those fields with the type's parameter `R`, and each clause
decides, field by field, whether it receives a field as it is or already
matched. The clauses read like a recursive function, but `fp.match` runs them as
a loop over an explicit stack, so a value a million levels deep does not
overflow the native stack. Every match ends, because a `Node` value is a finite
acyclic graph.

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
- **Ask for a field evaluated.** The clause parameter `Add[Int]` asks for both
  fields as the result type: they arrive as the results of matching the two
  children with the same clauses. `render` asks for `Add[String]` and gets the
  rendered children.
- **Ask for a field as it is.** `If[Int, E]` asks for the condition evaluated
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
- **Go deep.** The match keeps its pending values on an explicit stack and
  releases values in a loop. `deep` nests a million `Add` values, and
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
every value is a finite acyclic graph. Evaluated fields are parts of the value
being matched, and `Next` must continue with a value of smaller height, so a
match always ends. The argument is in
[guarantees and their sources](../architecture/matching.md#guarantees-and-their-sources).

The last chapter combines these pieces in a
[configuration processor](application.md).
