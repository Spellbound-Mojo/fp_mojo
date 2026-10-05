# fp.control

You need `fp.control` to write a loop as an expression that returns its final
value instead of updating variables in a `for` or `while` statement. The
program below shows each loop form; the
[iteration tutorial](../tutorial/iteration.md) covers folds over iterators.

<!-- api: control -->

## Write loops and a scan as expressions

<!-- example: docs/examples/control_flow.mojo -->

`while_loop(below_ten, double, 1)` doubles `1` until the carry is no longer
below ten, and returns `16`. `fori_loop(0, 5, add_index, 0)` adds the indices
0 to 4 and returns `10`. `scan(running_total, 0, xs^, reverse=True)` visits
`3`, `2` and `1`, so the carry ends at `6`, and returns the outputs in input
order, `[6, 5, 3]`.
