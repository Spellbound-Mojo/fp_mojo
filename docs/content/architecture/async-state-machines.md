# Explicit async state machines

The async runtime uses ordinary typed Mojo structs to represent suspended work.
Applications compose `IO[T, E]` values; `IO`'s run loop sequences them and runs
typed machines as leaves. It is implemented in `src/fp/effects/_async`; the
public application surface is `fp.effects.async_runtime`, with extension
contracts in its `protocols` module.
The modules under `experiments/async-state-machines/state_machine/` forward to
those canonical owners for the maintained qualification clients.

The implementation is pure Mojo: no compiler coroutine intrinsics, C backend,
assembly, or direct FFI calls. Cats and Cats Effect inform sequencing and
lifecycle semantics; native Mojo ownership, origins, and exact error types govern
the representation. See the [application guide](../guides/async-runtime.md) for
supported operations and the Cats mapping.

## Execution and outcomes

A public `Machine` declares concrete `Value` and `Error` types, and
`IO[T, E].lift` runs one as a leaf. Its mutating `poll` receives the canonical
context and returns either `Step.pending(wait)` or `Step.ready(outcome)`. A poll
must return cooperatively; it cannot block while waiting for external work or
rely on preemption. A lifted machine must own its state, or borrow only what `T`
or `E` already names.

Pending work and completed cancellation are distinct. A terminal outcome uses
the existing `Outcome[T, E]`: absence means cancellation-only, success owns `T`,
and failure owns an ordered nonempty error collection with an independent
cancellation flag. Errors can coexist with cancellation and retain their exact
native types and origins. Resumable nodes use the canonical settlement and
error-combination helpers rather than a separate outcome policy.

Building an `IO` invokes no user callback. An unopened `IO` may be dropped;
entered work belongs to the linear, non-Deinitable `Driver`. Request cancellation,
continue polling until `Progress.completed`, then consume `finish()` exactly
once. There is no detach or asynchronous destructor. Internal task and slot
owners enforce complete draining; custom machines must still obey their protocol.

A terminal step certifies that entered work and cleanup finished, or that their
ownership transferred into the result. A notification or external submission
alone is not completion. Cancellation requests unwinding rather than destroying
a suspended machine. A noncooperating poll or nonterminating masked finalizer can
prevent shutdown.

## Scoped ownership

`Scope` owns acquisition, use, cleanup, and the resource between them:

| Phase | Ownership and cancellation |
|---|---|
| Unopened | Cancellation skips acquisition and entered-work cleanup. |
| Acquiring | Mask the ownership handoff before observing cancellation. |
| Using | Lend the resource to each body poll; entered use drains on cancellation. |
| Cleaning up | Lend the resource and original exit case; remain masked across suspension. |
| Completed | Combine outcomes and destroy the resource only after cleanup finishes. |

`ScopedMachine` and `CleanupMachine` receive a fresh immutable resource borrow
for each poll; `Resource.use_scoped` and `Resource.make_case` take them. Stored state and returned values/errors cannot depend on that
fresh loan. A parser can retain its offset and reborrow a buffer on its next poll;
it cannot retain a pointer into the movable scoped owner between polls.
Independent external captures and results retain their native origins.

Cleanup borrows the original `ExitCase`, including move-only body errors. Nested
resources release in reverse acquisition order. Async resources and finalization
reuse canonical outcome, cancellation and resource policies; only their resumable
phase transitions belong to the async interpreter. See
[composition](async-composition.md) and [finalization](async-finalization.md).

## Scheduling and host integration

Execution slots own generation-checked registrations in the shared wake registry.
Signals preserve notification between inspecting state and parking. Ready child
queues use FIFO links; duplicate notifications do not create duplicate queue
entries. Timers use checked `Duration` and opaque `Instant`, with stale-entry
compaction and reusable registration storage.

`Driver.poll(budget)` bounds root polls plus timer events, not all nested child
polls, instructions, destructor work or notification fanout. Within each root
poll, `IORuntimeConfig.auto_yield_threshold` bounds the `IO` transitions of the
whole task tree; native callbacks and custom polls stay uncounted.
`Progress.transitions` and `Progress.quiescent` report the work done and whether
the program awaits external input. The driver does not sleep. Hosts deliver available events, drive runnable work, and arrange another
call for an external notification or the earliest reported deadline. A zero
budget only observes status. Manual clocks support deterministic driving.

The blocking `run` convenience uses the same driver with an idle-sleep fallback.
There is no OS I/O readiness backend or foreign-thread completion bridge. The
qualified runtime executes cooperatively on one host thread. See the
[scheduler](async-scheduler.md) for registration and parking details.

`IO` sequencing, iteration, recovery, finalization, and masks run on the run
loop. Fixed pairs, callback withdrawal, coordination, races, timeouts, and
resources are leaves. The private [nursery](async-nurseries.md) bounds lifetime
admissions until fibers replace it; [queue and semaphore](async-coordination.md)
handles provide reusable coordination. Leaf type depth and retained payload sizes
remain caller-visible costs.

## External and heterogeneous work

Scheduling does not encode device identity or stream policy. A future leaf may
own a batch of kernels or transfers and their dependencies while presenting one
host completion boundary. It must retain buffers, access rights and handles
until outstanding work drains. A fresh per-poll borrow cannot authorize access
after that poll returns, and a readiness notification is not device-memory
synchronization.

Cancellation can stop new submissions while already submitted work drains.
Timeout expiry therefore does not establish that external execution has stopped.
Completion and cleanup failures use the same typed outcome policy. GPU execution
and foreign-thread notification require separately qualified adapters; neither is
implemented here. The architecture has no identified fundamental obstacle to
host GPU orchestration.

## Qualification

The maintained clients under `experiments/async-state-machines/tests/` cover
public and generic clients, exact ownership and errors, scoped and external
origins, cancellation checkpoints, structured draining, timer arithmetic, stale
registrations, and compiler rejection diagnostics. Source and precompiled-package
routes run at O0/O3. Iteration and static-depth clients also run with a bounded
native stack. Compiler crashes and timeouts are failures, not expected rejections.

From the repository root in the pinned Mojo environment:

```sh
pixi run python experiments/async-state-machines/qualify.py \
  --output .cache/async-foundation-check --jobs 2 \
  --client foundation --client public_extension --client host_admission
```

Use a fresh output directory. The [overnight qualification](async-qualification.md)
records completed sustained reuse, ownership, retained-storage and performance
checks. The supported surface remains an opt-in preview on pinned Mojo 1.2.0
Linux x86-64; qualification does not extend to arbitrary platforms, parallel
payload execution, GPU adapters, or unlimited leaf type depth.
