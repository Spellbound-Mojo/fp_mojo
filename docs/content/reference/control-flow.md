# fp.control

`fp.control` expresses loops as functions that pass an accumulator, or carry,
from one step to the next. `while_loop` and `fori_loop` return the final carry;
`scan` also collects an output from each step. For folds over native iterators,
see the [iteration tutorial](../tutorial/iteration.md).

<!-- api: control -->

## Write loops and a scan as expressions

<!-- example: docs/examples/control_flow.mojo -->

`while_loop(below_ten, double, 1)` doubles `1` until the carry is no longer
below ten, and returns `16`. `fori_loop(0, 5, add_index, 0)` adds the indices
0 to 4 and returns `10`. `scan(running_total, 0, xs^, reverse=True)` visits
`3`, `2` and `1`, so the carry ends at `6`, and returns the outputs in input
order, `[6, 5, 3]`.
