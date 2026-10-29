# Structured races and timeouts

The private pure-Mojo package implements the
[structured control contract](async-control-plan.md) with `race(left, right)`
and `timeout_to(program, duration, fallback)`.

Race uses the existing child pair's independent tokens, execution slots, FIFO
selection, and drain tracking. Exactly one ready child is polled per race poll.
The first child observed terminal selects the result, whether success, error,
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

Timeout starts its Sleep deadline when the wrapper is first entered, before the
timer child gets a poll. The timer competes through the same Race implementation.
Typed bind selects either the original value or the owned fallback recipe.
Its private machine branch uses the standard library Variant directly, avoiding
reflected data-family admission over entire nested machine types. Public race
values still use the existing Choice and Left/Right constructors.
Fallback requires the same value and error types, remains unopened while losing
work drains, and is skipped on cleanup failure or parent cancellation. Deadline
expiry requests cancellation; it does not bound time spent draining masked work.
Zero-duration timeouts use the same observation-order rule, so an immediately
terminal program can win the initial left-first tie.

No new public `fp` exports, OS integration, or cross-thread execution guarantees
are introduced. `_Pair` now separates a request to drain from its default
failure trigger; existing `both` and scoped pairs retain their policy. Sleep's
deadline initialization is shared by ordinary sleep and timeout entry.

## Validation

The race client checks 32 terminal-result/order combinations, both cancellation
directions, suspended losing cleanup, parent cancellation after selection,
movement during draining, exact destruction, deadline anchoring under a one-poll
budget, fallback entry after withdrawal, cleanup failure, and retired metadata.
Native-origin clients cover winner values, errors, and fallback values. Compiler
rejections cover mismatched child errors, mismatched fallback types, and escaped
winner origins. Existing pair, nursery, scope, scheduler, and synchronous tests
remain in the source/package O0/O3 qualification matrix.

The deeply composed timeout and borrowed-origin clients have explicit 240-second
compile budgets; execution retains the 15-second limit. Other budgets are
unchanged. `qualify.py --client NAME` selects a focused client matrix (repeat
the option for several clients), and reports the selection explicitly. Omitting
that option runs the complete inventory.

The initial `qualification-racing-1` run passed 190 of 196 checks, both package
builds, and all 12 bounded-stack executions. Six compilations reached the original
120-second limit: all four borrowed-origin builds and both optimized timeout
builds. No executed client failed. After simplifying the private branch storage
and recording the larger compile budgets, `qualification-racing-focused-1`
passed all eight source/package O0/O3 checks for those two clients. Both runs
passed input-stability checks; original timeout diagnostics remain in the first
report. Documentation checks pass. The subsequent
[complete control-pass qualification](async-finalization.md#validation) passed all
228 checks, both package builds, and 12 bounded-stack executions, covering this
implementation together with the integration workload and finalization adapters.
