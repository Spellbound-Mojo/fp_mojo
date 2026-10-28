# fp.control

`fp.control` expresses loops as functions that pass an accumulator, or carry,
from one step to the next. `while_loop` and `fori_loop` return the final carry;
`scan` also collects an output from each step. For folds over native iterators,
see the [iteration tutorial](../tutorial/iteration.md).

Use `fori_loop_mut(lower, upper, body, carry)` when a named library body needs
exclusive access to its receiver. Its updates remain in `body` after the call,
including updates made before a raised error. The body implements
`MutableBinary` or `Binary` with `(Int, Carry) -> Carry`; mutable invocation wins
when both are available, matching `call_repeated`. `fori_loop` keeps its shared
receiver behavior. Native functions and closures continue to use `fori_loop`.

The mutable entry point has the same static form,
`fori_loop_mut[lower, upper, unroll=0](body, carry)`, and the same bounds and
unrolling semantics. It borrows the callback, so pass a named mutable variable.
Neither the callback nor carry is copied. Generic wrappers can forward any
repeatable binary callback using its exact `Error` type.

<!-- api: control -->

## Write loops and a scan as expressions

<!-- example: docs/examples/control_flow.mojo -->

`while_loop(below_ten, double, 1)` doubles `1` until the carry is no longer
below ten, and returns `16`. `fori_loop(0, 5, add_index, 0)` adds the indices
0 to 4 and returns `10`. `scan(running_total, 0, xs^, reverse=True)` visits
`3`, `2` and `1`, so the carry ends at `6`, and returns the outputs in input
order, `[6, 5, 3]`.

The mutable counted-loop example retains its increasing weight in `body`.
The four steps produce `20`, and the body records four calls after the loop.
