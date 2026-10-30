# Async finalization and lexical masking

`IO` provides `guarantee`, `guarantee_case`, and `on_cancel`, and
`IO.uncancelable` with `Poll` and `io.restore(poll)`. The run loop implements
them as frames over the canonical execution and outcome owners. The typed
scope-based machines described below remain private leaves for typed parts.

## Finalization

A finalize frame settles the body's outcome, then runs the cleanup program masked
with the exact exit. A finish frame restores the context and merges body and
cleanup errors through canonical `_finish`, then settles. The exit is held in
`_ExitState`, so `ExitCase`, `_finish`, `_settle`, and cancellation settlement
remain the only finalization and error policies.

`guarantee` runs an ordinary cleanup `IO` and discards its successful value.
`guarantee_case` takes a factory that borrows the exact `ExitCase` and builds the
cleanup `IO`; the factory's error becomes a cleanup failure. `on_cancel` runs
cleanup only when the body exit records cancellation, including failure plus
cancellation, and otherwise drops it unopened. Body and finalizer errors retain
their exact types and origins, ordered body first and then inner-to-outer
finalizers. Cleanup is masked across waits.

A finalizer installed by a continuation that already ran is armed, as in Cats
Effect: cancellation observed at the body's first checkpoint runs it. An unopened
`IO` runs neither body nor finalizer. The typed `Guarantee` machine adapts to the
existing `Scope` instead: a unit resource marks entry, cleanup borrows the exit
on each poll, and a typed guarantee that never entered skips its cleanup.

## Masks and Poll

`IO.uncancelable(factory)` checks cancellation, enters a new mask, and invokes a
consuming factory with a copyable `Poll[E]`; it then runs the `IO` the factory
builds. Factory errors are captured with their exact compatible error type. A
successful terminal result produced inside that mask survives to its owner.
Starting another unmasked operation (for example a bind continuation) observes a
pending cancellation request. Entry into a masked region remains a cancellation
checkpoint. The private typed `uncancelable_with` machine shares the same mask and
`Poll` owners.

The async execution step records protected success privately; execution slots
and the run loop pass that fact to the canonical settlement helper. Region exits
and Poll restoration preserve it, without changing the public Outcome shape.
Errors still retain an independent cancellation flag. A resource scope observes
the body's protected exit, then its own post-cleanup settlement remains a
checkpoint. Synchronous IO keeps its existing settlement behavior.

`io.restore(poll)` restores the cancellation state preceding the poll's region
(`poll(fa)` in Cats Effect); the typed `poll.apply(program)` does the same.
The canonical synchronous Poll owns a shared private restoration helper,
which both runners use. It restores the mask and lexical region while retaining
the current invocation's token, clock, scheduler, and parent registration.
Reusing a captured scheduler parent would attach nested children to the wrong
execution slot. Existing synchronous finalization regressions qualify this
shared change.

A Poll only restores its matching current region. Outer polls cannot pierce a
nested mask or a finalizer's new mask. Restoring an already masked enclosing
context remains masked. Child tasks retain their independent tokens and regions.
An escaped Poll is inert outside its region and cannot restore its old canceled
token into a later task. Its owned marker and context metadata contain no pointer
to a finished stack frame; retained handles may extend metadata ownership.

## Validation

Tests cover all 16 body/parent-cancellation/cleanup-error combinations, scoped
borrowing of move-only body errors across cleanup suspension, on_cancel selection,
unopened programs, retained body owners, nested error order, and movement during
cleanup. `io_finalization` covers the same cases for `IO`'s frames, and `io_depth`
unwinds a failure through 100,000 nested finalizers under a 1 MiB stack. Mask tests cover active and stale Poll handles, nested regions, restored
structured children, manual-clock waits, finalizer protection, and factory errors.
Native-origin clients cover body values/errors, finalizer captures, factories,
and restored results. Negative clients reject escaping exit borrows, incompatible
error families, and escaped masked results.

The maintained source/package O0/O3 qualification includes checkpoint, lexical
masking, scope ownership and synchronous IO regression clients. The
[overnight workload](async-qualification.md) adds sustained suspending withdrawal,
cleanup failures, cancellation draining and exact ownership checks. Public
release scope remains the [opt-in preview](../guides/async-runtime.md).
