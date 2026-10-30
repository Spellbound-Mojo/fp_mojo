# Typed callback registration

`IO[T, E].async(register, withdrawal)` runs the private `Callback` leaf, which owns
a one-shot registration callable accepting `Completion[T, E]` and returning unit.
Its native error is `E` or `Never`; the withdrawal is a unit `IO` with the same
`E`, and `IO.async_` has none. Native functions and library callables use the
canonical invocation adapters. The [composition engine](async-composition.md)
owns execution in pure Mojo.

The private [nursery](async-nurseries.md) admits callback machines dynamically and
joins them through their complete withdrawal.

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
canonical coordination guard without blocking. The supported boundary is cooperative,
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

The [overnight qualification](async-qualification.md) also exercises sustained
callback reuse, exact payload destruction and retirement of subscriptions.
Foreign-thread callback producers require a separately qualified integration.
