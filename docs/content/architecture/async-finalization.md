# Async finalization and lexical masking

The private package provides `guarantee`, `guarantee_case`, `on_cancel`,
`uncancelable`, and `uncancelable_with`/`Poll` for resumable machines. Runtime
code remains pure Mojo and public synchronous operation signatures are unchanged.

## Finalization

All three finalization constructors adapt to the existing Scope. A unit resource
marks entry into the protected operation. The body delegates through the same
scoped-program adapter now shared with Semaphore's permit scope. Cleanup uses
canonical ExitCase, `_ExitState`, `_discard`, `_finish`, and cancellation
settlement; there is no second finalization state machine or error policy.

`guarantee_case` takes a ScopedMachine whose Input is the exact ExitCase type.
It borrows that exit only for each poll, including after suspension; neither
its result nor its stored fields may escape that borrow. `guarantee` runs an
ordinary cleanup machine and discards its successful value. `on_cancel` runs
cleanup only when the body exit records cancellation, including failure plus
cancellation. Body and finalizer errors retain their exact types and origins,
ordered body first and then inner-to-outer finalizers.

Entering the guarantee installs the scope before body execution. Cancellation
between that entry and the body's first poll still finalizes the entered scope.
An entirely unopened recipe runs neither body nor finalizer. A completed body
value remains owned until cleanup finishes; late cancellation can suppress it
only after cleanup drains. Cleanup is masked across waits and task movement.

## Masks and Poll

`uncancelable_with[E](factory)` invokes a consuming typed factory under a new
mask and gives it a copyable `Poll[E]`. Factory errors are captured with their
exact compatible error type. `uncancelable(program)` uses the same implementation
with a constant factory. Pending cancellation is observed when the mask returns
to an unmasked enclosing context.

`poll.apply(program)` restores the cancellation state preceding its own region.
The canonical synchronous Poll now owns a shared private restoration helper,
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
unopened recipes, retained body owners, nested error order, and movement during
cleanup. Mask tests cover active and stale Poll handles, nested regions, restored
structured children, manual-clock waits, finalizer protection, and factory errors.
Native-origin clients cover body values/errors, finalizer captures, factories,
and restored results. Negative clients reject escaping exit borrows, incompatible
error families, and escaped masked results.

The complete `qualification-control-final-1` run passed all 228 checks: 22 positive
clients, 26 rejection clients, and nine synchronous regression clients, each
through source and separate-package imports at O0/O3 with warnings as errors.
Both package precompilations and all 12 bounded-stack executions passed. Command
audits reported no failures, and source and experiment inputs remained unchanged
throughout the run. This matrix includes races, timeouts, and the 32-cycle
producer/worker workload as well as finalization and masking.

The local report and raw diagnostics are retained at
`.cache/state-machine-foundation/qualification-control-final-1/report.json`.
Qualification used Mojo 1.2.0 (`2016d0cd`) on Linux x86-64. Documentation checks
also pass. See the [public API readiness review](async-public-api-review.md) for
the supported-release decisions still to be made.
