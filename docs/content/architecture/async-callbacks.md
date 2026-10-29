# Typed callback registration

This private extension of the [state-machine experiment](async-composition-implementation.md)
keeps all implementation in Mojo. `callback(register, cleanup)` admits a native
one-shot callable accepting `Completion[T, E]` and returning `NoneType`. Its exact
native error is `E` or `Never`; cleanup is a `Machine` returning `NoneType` with
the same `E`. No production async API is exported.

## Ownership and terminal decisions

Cleanup is owned **before** registration begins. Registration is synchronous and
bounded; it may retain a copy of the completion handle, finish immediately, or
raise after partial registration. Cleanup must support that partial state and
runs after every entered registration. Producer state needed for withdrawal must
be owned by cleanup or independently shared. A task canceled before entry starts
neither registration nor cleanup.

Completion handles share an owned cell. The first completion or observed
cancellation closes it; subsequent attempts return `False` and drop their input.
A retained handle remains valid after its task finishes. Exact value/error types,
including origins, are carried through the cell; copies do not extend borrowed
owners' lifetimes. Payload destruction occurs outside the cell guard.

The callback waits on the signal revision captured before examining the cell,
preserving wakeups during the inspection/parking interval. Polling attempts the
canonical coordination guard without blocking. This pass qualifies cooperative,
single-threaded use and deterministic race orderings. It does not claim a
cross-thread producer contract or provide an OS event source.

## Cleanup, errors and cancellation

Cleanup runs masked and may suspend. Cancellation already delivered to the
callback does not continually wake parked cleanup. The task cannot finish until
cleanup finishes, even when registration completed its callback immediately.

Errors retain the canonical ordering: callback error, registration error, cleanup
error. Registration failure without a callback outcome is an error without an
invented cancellation flag. Cancellation remains independent of failure and is
recorded at the existing settlement checkpoints; a callback success followed by
parent cancellation before task completion can therefore become cancellation.

## Qualification

`experiments/async-state-machines/qualify.py` exercises immediate, delayed,
duplicate and late completion; all 32 combinations of producer outcome,
registration error, cleanup error and parent cancellation; masked suspension;
task movement; an independently scheduled producer; move-only destruction; and
borrowed captures, results and errors. Negative clients reject origin escape and
incompatible cleanup errors. The gate also reruns canonical coordination tests
because the nonblocking guard helper is shared with synchronous `Ref` locking.

The matrix runs source and precompiled packages at `-O0` and `-O3` with warnings
as errors. Compiler rejection counts only when the expected diagnostic appears;
crashes and timeouts fail qualification. Each run retains hashes, commands,
diagnostics and binaries under its chosen cache directory.

Qualification on Linux x86-64 with Mojo **1.2.0 (2016d0cd)** passed **112/112**
matrix checks, both package precompilations, and **12/12** executions under a
1024 KiB stack limit. Input and artifact audits passed. Evidence is retained in
`.cache/state-machine-foundation/qualification-callbacks-1/report.json`.
The origin-escape fixture was then simplified to remove an unrelated aliasing
diagnostic and rechecked in all four configurations; no runtime code changed.
That focused evidence is in
`.cache/state-machine-foundation/callback-negative-fix/report.json`.
The documentation build and link/export inventory also passed. The full
repository suite and cross-thread callback behavior were not tested.
