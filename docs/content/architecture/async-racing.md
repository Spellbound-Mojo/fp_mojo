# Structured races and timeouts

`IO` exposes first-terminal selection through `race_first` and `timeout_after`,
and cancellation-aware selection through `race` and `timeout_to`. Each method
starts its sides as [fibers](async-fibers.md) of the running fiber and waits in a
private leaf that only forwards cancellation and combines outcomes; fibers own
and drain the children. `race_pair` exposes the same start, producing the first
side's outcome and the other side's fiber. All are part of the opt-in preview.

Each side has its own token, and the host ticks ready fibers in FIFO order, so a
root poll can advance both sides. With `race_first`, the first child observed terminal selects the result, whether success, error,
or cancellation. This is first terminal completion, not first successful value.
Initially ready ties favor the left child; later ties follow scheduler readiness
order. There is no external timestamp arbitration.

Success is `RaceResult[A, B]`, a `Choice` of existing `Left[A]` and `Right[B]`
constructors. Identical arm types remain distinguishable. Both children require
the same exact error type. Values and errors may be move-only or retain external
native origins.

Selection cancels unfinished children, and return waits until both are terminal.
The losing success is destroyed. Losing cancellation is expected and does not
cancel the selected result; losing errors are retained with their cancellation
flag normalized, then combined through canonical `_finish`. Selected errors
precede losing errors. Parent cancellation is independently settled by the
enclosing slot and suppresses success or marks retained failures canceled.
Masked losing cleanup can suspend and does not spin after cancellation delivery.

`race` uses the same polling and draining engine. If the first terminal outcome
is cancellation-only, it selects the other child's result after cancellation
and draining. A masked child can therefore supply a surviving success or failure.
Both canceled children yield terminal cancellation, including under an enclosing
mask; unlike Cats Effect's masked cancellation-only case, this runtime does not
turn that explicit outcome into an indefinite wait. Selected failures retain
their cancellation flag, while cancellation on the discarded side is normalized.

A timeout starts the source as a fiber and anchors its deadline on the leaf's
first poll, when the wrapper is entered and before the source's first poll. The
deadline, not a timer fiber, competes with the source; a bind after the leaf
keeps the source's value or runs the owned fallback. Public race values use the
existing Choice and Left/Right constructors.
`timeout_after` preserves the original timer-selection policy: timer victory
selects fallback after clean draining even if source success survives.
`timeout_to` instead prefers any source success or failure observed after
draining; fallback is selected only for cancellation-only source completion.
Both policies keep the same admission and ownership path.

Fallback requires the same value and error types, remains unopened while losing
work drains, and is skipped on cleanup failure or parent cancellation. Deadline
expiry requests cancellation; it does not bound time spent draining masked work.
Zero-duration timeouts use the same observation-order rule, so an immediately
terminal program can win the initial left-first tie.

One private pair leaf serves `both`, `race`, and `race_first` by policy: a race
cancels the other side once one finishes, and `both` cancels it when one side
ends unsuccessfully. Outcomes combine through the canonical `_winner`, `_loser`,
`_finish`, and `_zip_outcomes`; there is no other child-draining policy.

## Validation

`selection_policies` covers both race directions after first-child cancellation,
protected source success after deadline expiry, late errors, canceled sources,
fallback admission, parent cancellation, and explicit cancellation under masks.
The first-terminal policy clients explicitly use `race_first` and `timeout_after`.

The race client checks 32 terminal-result/order combinations, both cancellation
directions, suspended losing cleanup, parent cancellation after selection,
movement during draining, exact destruction, deadline anchoring under a one-poll
budget, fallback entry after withdrawal, cleanup failure, and retired metadata.
Native-origin clients cover winner values, errors, and fallback values. Compiler
rejections cover mismatched child errors, mismatched fallback types, and escaped
winner origins. Existing pair, fiber, scope, scheduler, and synchronous tests
remain in the source/package O0/O3 qualification matrix.

`qualify.py --client NAME` selects a focused source/package O0/O3 matrix; repeat
that option for multiple clients. Compile and execution budgets live in the
runner, and each run retains raw diagnostics and independently audited results.
The [integration workload](async-workload.md) combines these policies with
resources, callbacks, queues and permits; [overnight qualification](async-qualification.md)
adds sustained retirement and retained-storage checks.
