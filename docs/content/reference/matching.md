# fp.matching

You need `fp.matching` to match a value of a declared data type, a `Result`, an
`Optional` or several values at once, and to rewrite recursive values. The
tutorial introduces it in [data and matching](../tutorial/matching.md) and
continues with [recursive data](../tutorial/recursion.md).

<!-- api: matching -->

## Evaluate, render and rewrite a recursive type

<!-- example: docs/examples/expression.mojo -->

`evaluate` asks for the fields of `Add` and `Mul` evaluated and returns `10` for
`Add(Mul(1, 6), Add(4, 0))`. Its `If` clause returns `Next` with the chosen
branch, so `If(zero, big, 7)` returns `7` without evaluating `big`. `simplify`
uses `fp.rewrite` with guarded clauses and returns `(6 + 4)`. The last two
matches evaluate a value built from 61 doublings of one shared node, and a value
a million levels deep.

## Match several values at once

<!-- example: docs/examples/traffic_light.mojo -->

`step` matches a light and an event together, so its clauses cover every pair
of constructors; four ticks from red give green, amber, red and green.
`report` adds a plain `Int` as a third value, and its guard `n > 3` selects
`"red with a queue of 5"`.
