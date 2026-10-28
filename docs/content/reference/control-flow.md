# fp.control

`fp.control` expresses loops as functions that pass an accumulator, or carry,
from one step to the next. `while_loop` and `fori_loop` return the final carry;
`scan` also collects an output from each step. For folds over native iterators,
see the [iteration tutorial](../tutorial/iteration.md).

Use `fori_loop_mut(lower, upper, body, carry)` when a named library body needs
exclusive access to its receiver. Its updates remain in `body` after the call,
including updates made before a raised error. The body implements
`MutableBinary` or `Binary` with `(Int, Carry) -> Carry`; mutable invocation wins
when both are available, matching `call_repeated`. Native functions and closures
continue to use `fori_loop`.

Ordinary `fori_loop` also accepts a moved or temporary library body. Use
`fori_loop(0, 4, body^, carry)` when the loop owns its callback, or
`fori_loop(0, 4, mut_ref(body), carry)` to retain the updated body. Both prefer
mutable invocation before shared invocation and reject consuming-only callbacks.
A named shared body remains borrowed and uses its shared receiver. The same
rules apply to `fori_loop[lower, upper, unroll=0](body^, carry)`. An owned body
is consumed and destroyed even when the bounds are empty.

The mutable entry point has the same static form,
`fori_loop_mut[lower, upper, unroll=0](body, carry)`, and the same bounds and
unrolling semantics. It borrows the callback, so pass a named mutable variable.
Neither the callback nor carry is copied. Generic wrappers can forward any
repeatable binary callback using its exact `Error` type.

Use `while_loop_mut(predicate, body, carry)` for a named unary body that needs
exclusive access to its receiver. It accepts `MutableUnary` or `Unary` with
`Carry -> Carry`, prefers mutable invocation when both are present, and keeps
receiver updates after success or failure. The predicate reads the carry before
each step; a false result returns that carry without a body call. The carry and
callback are never copied, and failure stops before the next predicate call.

Predicates can use shared `BorrowCallable` or mutable `BorrowMutableCallable`
receivers, or be plain functions or stored thin pointers. Move a stateful
predicate with `predicate^`, or pass `mut_ref(predicate)` to retain it after the
loop. A moved or temporary predicate uses mutable invocation before shared;
named shared predicates remain borrowed. Consuming-only predicates cannot
repeat. The example retains a predicate that allows three steps, then inspects
its four checks, including the final false result. Capture a closure or pointer alias once with
`BorrowSignature[A, Bool, E].capture(callback)`, then reuse the named predicate.
`E` defaults to `Never`. Predicate and body errors must be the same exact type,
including origins, or one must be `Never`; `while_loop` keeps its shared-body
behavior.

Generic wrappers can name the exact combined error with
`while_loop_mut[E=MyError](predicate, body, carry)`. For example, a generic
non-raising predicate and a body `F` can use `E=F.Error`, matching the wrapper's
`raises F.Error`. Ordinary calls infer the error. The explicit selection must
equal that inferred error, so it cannot widen or replace an error type.

A library `scan` step returns `(next_carry, output)`. Its output type is inferred;
`scan[Y](step, carry, source)` remains available when explicit selection is useful.
Pass a moved or temporary shared or mutable step to transfer ownership, or
`mut_ref(step)` to inspect its state after the scan. Mutable invocation wins for
owned steps; named shared steps remain borrowed. Consuming-only steps cannot
repeat. This applies to Lists, finite iterators and scans without an input.

Iterator inputs are fully collected before any step runs. Length validation then
runs before callbacks; a mismatch releases the owned step, carry and input.
Callback failures stop immediately and preserve their exact type inside
`ScanStepError`, including `StopIteration`. Reverse scans invoke the callback in
reverse input order but return outputs in their original positions.

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
The owned example passes `Weighted(0)` directly to `fori_loop` and also returns
`20`, without introducing a named callback or selecting a different operation.

The mutable while-loop example reuses a captured predicate and increases its
step size through `advance.calls`: the carries are `0`, `1`, `3`, `6`, `10`.
The result is `10`, and the body retains four calls.

The owned scan example passes `WeightedScan(0)` directly. Its state increases the
weight on each input, producing carry `14` and outputs `[1, 5, 14]`. The output
type is inferred from the callback's pair result.
