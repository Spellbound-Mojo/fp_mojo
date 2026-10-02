# 6. Recursive data

A recursive data type has constructors whose fields hold values of the same
type. The type marks those fields with its parameter `R`; a clause then decides,
field by field, whether it wants the field as it is or already matched. No
clause calls the match recursively: the library evaluates the fields a clause
asks for, in a loop, and passes their results in.

## Evaluate, render, simplify

<!-- example: docs/examples/expression.mojo -->

- **Declaring.** `Add[R]` has two fields of type `R`. In `Expr` the layer passes
  `R` on, so a stored `Add` holds two `Node[Expr]` values. A constructor such as
  `If[C, B]` may take more than one parameter, so that a clause can treat the
  condition differently from the branches; the layer passes `R` to each.
- **Fields that arrive evaluated.** The clause parameter `Add[Int]` asks for both
  fields as the result type: they arrive as the results of matching the two
  children with the same clauses. `render` asks for `Add[String]` and gets the
  rendered children.
- **Fields that arrive as they are.** `If[Int, E]` asks for the condition
  evaluated and the branches as stored. The clause returns `Next(...)`: the
  result of this value is the result of matching the chosen branch instead. The
  other branch is never evaluated, which is why `If(zero, big, 7)` returns 7
  without evaluating `big`, a product of 2^40 ones.
- **Rewriting.** `fp.rewrite` transforms a value bottom-up. Its clauses take the
  constructors that change, with recursive fields already rewritten, and return
  the new value. Every other value is rebuilt from its rewritten children, and a
  value whose children did not change is reused. A rewrite is one pass.
- **Sharing.** `Node` values are immutable and copying one shares it, so
  `Add(shared, shared)` refers to one value twice. The 62 levels of `shared`
  describe 2^61 leaves through 62 values, and a match evaluates each value once:
  the result of a shared value is computed once and copied.
- **Depth.** The match keeps its pending values on an explicit stack, and values
  are released in a loop, so a value a million levels deep is built, matched and
  dropped without native recursion.

## Lists and optional children

A recursive field may also be `List[R]` or `Optional[R]`:

<!-- example: docs/examples/file_tree.mojo -->

`Folder[Int]` receives the sizes of all its entries, and `Shortcut[Int]` the
size of its target when it has one. `listing` takes `Shortcut[T]`, the field as
stored, so a shortcut is printed without following it.

## What the guarantees rest on

A `Node` can only refer to values that already exist and never changes, so
every value is a finite acyclic graph. Evaluated fields are parts of the value
being matched, and `Next` must continue with a value of smaller height. A match
therefore always ends. The full contract, including costs and limits, is in
[algebraic data and matching](../architecture/matching.md).

The final tutorial combines these foundations in a [configuration processor](application.md).
