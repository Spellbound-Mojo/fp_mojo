# Structured async control and qualification

This accepted pure-Mojo work extends the private state-machine package in three
implementation passes, each qualified, committed, and pushed separately.

## Race and timeouts

`race(left, right)` owns both children and uses their existing independent tokens,
slots, ready selection, and draining policy. Exact error types must match.
The first observed terminal child wins, including failure or cancellation.
Successful values use `RaceResult[A, B]`, an existing inline `Choice` with the
existing `Left[A]` and `Right[B]` constructors. Both arms remain distinct when
A and B are the same type. No type, ownership, or origin erasure is introduced.

The losing child is canceled and drained before return. Losing success is
destroyed, losing cancellation is expected, and losing errors remain observable.
Error order is selected outcome first, then losing outcome. Losing cancellation
does not cancel a successful winner; parent cancellation is settled independently
at the enclosing slot. Ready ties follow scheduler FIFO order (left first on
initial admission), not an external physical completion timestamp.

`timeout_to(program, duration, fallback)` races against the existing Sleep timer
and sequences the result through typed bind. Its deadline starts on first entry,
before either child is polled. Fallback has the exact same value/error types and
remains unopened until timed-out work drains successfully. Cleanup failure
prevents fallback and is returned. Parent cancellation skips fallback. A deadline
requests cancellation; masked work and cleanup can delay actual completion.

Tests cover both winners, failure/cancellation selection, readiness ties, parent
cancellation before and after selection, suspended losing cleanup, retained
errors, native origins, move-only ownership, timers, and registration retirement.

## Integration workload

A deterministic bounded producer/worker workload combines queues, permits,
callback completion/withdrawal, deadlines, fallbacks, and structured ownership.
Repeat normal, timed-out, failed-cleanup, and externally canceled cycles while
checking progress, exact destruction, returned permits, late callback rejection,
and bounded/retired scheduler registrations. The host advances manual time and
delivers completion signals; no real-time sleeps or OS backend are required.

## Finalization, masking, and public API review

Add async `guarantee`, `guarantee_case`, `on_cancel`, `uncancelable`, and
`uncancelable_with`/`Poll` counterparts. Reuse canonical exit representation,
error accumulation, cancellation settlement, scope ownership, and restoration
rules. Scoped finalizers borrow ExitCase only for a poll. Cleanup stays masked
across suspension, and unopened recipes execute no cleanup.

Poll restores only its active lexical region; nested masks, child tokens, and
finalizers retain their boundaries. Scheduler parent metadata must come from the
current invocation, not a context captured before child-slot creation. Escaped
polls remain safe and inert outside their region. Factories preserve exact typed
errors and native origins.

Finish with a documented public API readiness review covering ergonomics,
ownership/linearity, error semantics, cancellation, qualification scope,
performance evidence, compatibility, and host integration. Review does not
automatically promote experimental exports or promise OS/cross-thread support.
