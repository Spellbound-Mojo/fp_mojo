# Structured races and timeouts

The private pure-Mojo package implements the
[structured control contract](async-control-plan.md) with `race_first` and
`timeout_after`, and cancellation-aware selection with `race` and `timeout_to`.
These spellings remain experimental until public promotion.

Race uses the existing child pair's independent tokens, execution slots, FIFO
selection, and drain tracking. Exactly one ready child is polled per race poll.
With `race_first`, the first child observed terminal selects the result, whether success, error,
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

Timeout starts its Sleep deadline when the wrapper is first entered, before the
timer child gets a poll. The timer competes through the same Race implementation.
Typed bind selects either the original value or the owned fallback recipe.
Its private machine branch uses the standard library Variant directly, avoiding
reflected data-family admission over entire nested machine types. Public race
values still use the existing Choice and Left/Right constructors.
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

No new public `fp` exports, OS integration, or cross-thread execution guarantees
are introduced. `_Pair` now separates a request to drain from its default
failure trigger; existing `both` and scoped pairs retain their policy. Sleep's
deadline initialization is shared by ordinary sleep and timeout entry.

## Validation

`selection_policies` covers both race directions after first-child cancellation,
protected source success after deadline expiry, late errors, canceled sources,
fallback admission, parent cancellation, and explicit cancellation under masks.
The original policy clients now explicitly use `race_first` and `timeout_after`.

The race client checks 32 terminal-result/order combinations, both cancellation
directions, suspended losing cleanup, parent cancellation after selection,
movement during draining, exact destruction, deadline anchoring under a one-poll
budget, fallback entry after withdrawal, cleanup failure, and retired metadata.
Native-origin clients cover winner values, errors, and fallback values. Compiler
rejections cover mismatched child errors, mismatched fallback types, and escaped
winner origins. Existing pair, nursery, scope, scheduler, and synchronous tests
remain in the source/package O0/O3 qualification matrix.

The deeply composed timeout, selection-policy, and borrowed-origin clients have explicit 240-second
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

The selection-policy pass passed 25 of 28 checks in
`selection-1`; three new selection-client compilations reached the 120-second
budget. Its package O0 execution and all legacy and rejection clients passed.
The original diagnostics remain in that report; the focused rerun uses the
240-second compile budget above. `selection-2` passed all four source/package
O0/O3 checks and both package builds, including exact destruction of a move-only
selected payload. Both reports passed input-stability checks. Runtime execution
limits are unchanged.
