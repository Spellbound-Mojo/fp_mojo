# Explicit async state machines

This page records the initial foundation checkpoint. The subsequent
[composition implementation](async-composition-implementation.md) extends it
with sequencing, loops, and structured child ownership; consult that page for
the current implementation and qualification scope.

The selected direction is a pure-Mojo runtime built from explicit state
machines. The user accepted an execution/API redesign and scoped borrowing on
October 28, 2026. Cats and Cats Effect inform the algebra and lifecycle semantics;
Mojo's native ownership, origins, and exact error types govern the representation.

The first private prototype lives in `experiments/async-state-machines/`. It
establishes a resumable protocol, cooperative execution, cancellation, and
suspending resource cleanup. It introduces no public `fp` exports and does not
change existing synchronous IO behavior. Its runtime and behavioral probes are
Mojo, with no coroutine intrinsics, C backend, assembly, or direct FFI calls.
The qualification script uses the repository's existing Python developer tools.

## Execution contract

`Machine` associates a concrete `Value` and `Error` with its stored state.
`poll(mut self, context)` makes one bounded, nonblocking step and returns
`Step[Value, Error]`. A step is either:

- Completed, carrying the existing `Outcome[Value, Error]` unchanged in shape.
- Pending, carrying a wait condition: runnable again, a signal revision change,
  a monotonic deadline, or cancellation where observation is allowed.

Pending and completed cancellation are distinct. `Step` uses an outer Optional
for completion; the inner `Outcome` can be absent to represent cancellation.
Errors remain exact payloads inside the canonical `EffectFailure`, including
move-only errors and borrowed origins. Native raising endpoints will need to
capture their errors before returning a step; there is no new error-erasure path.

`Task[P]` retains the concrete machine type and its captured origins. It is
movable and explicitly **not Deinitable**. The owner must drive it to completion
and consume it with `finish()`. Finishing an incomplete task aborts as an internal
contract violation. This prevents ordinary task abandonment from silently
discarding entered finalizers. It cannot protect against process termination,
unsafe manipulation, or bypassing the task driver to manually drop a polled
machine. Custom machines must obey the protocol.

Cancellation is cooperative. A request makes an interruptible parked task
eligible for another poll; it does not destroy its machine. The machine resumes
and completes its cleanup. Masked acquisition and cleanup waits retain their
readiness conditions even when cancellation has been requested. A finalizer
waiting for a condition that never arrives can therefore keep a task alive.

The driver polls each ready task at most once per round. A custom poll that
blocks or loops indefinitely blocks the driver; this prototype provides no
preemption or automatic yield injection.

## Resource ownership and scoped borrows

`Scope[Acquire, Use, Cleanup]` owns the resource. Its lifecycle is:

| Phase | Work | Cancellation behavior |
|---|---|---|
| Unopened | Check cancellation before acquisition | Skip all work if already canceled |
| Acquiring | Poll acquisition under a mask | Complete the ownership handoff before observing cancellation |
| Using | Lend the resource to each body poll | Skip unopened use on cancellation; resume entered use so it can unwind |
| Cleaning up | Lend the resource and original exit case to each cleanup poll | Remain masked through all cleanup suspensions |
| Completed | Combine outcomes, destroy the resource, return | Preserve errors and cancellation independently |

`ScopedMachine.poll[p: ImmOrigin]` and `CleanupMachine.poll[p: ImmOrigin]`
receive a fresh immutable resource borrow for that call. Their stored state and
associated result/error types cannot depend on that fresh origin. For example,
a parser can store its offset between polls and borrow the buffer again on the
next poll. It cannot store a pointer into its scope's movable resource.

This is an intentional contract change from retaining an arbitrary native
borrow across suspension. External captures still carry native origins through
the task and its outcome. Borrowing within a poll remains ordinary Mojo
borrowing; resource-dependent views must be recreated on later polls. The first
protocol supports immutable resource borrows; a mutable resource protocol is
not qualified here.

Cleanup borrows the original `ExitCase`, including move-only body errors. The
resource stays owned until cleanup finishes. Error order, cancellation marking,
and finalization outcome policy delegate to the existing `_settle`, `_ExitState`,
`_finish`, and `_scope_failure` implementations. The prototype owns only the
resumable phase transitions. Generic `rebind` operations resolve associated
types after exact compile-time equality assertions; they do not erase origins.

The phase coordinator is experimental. Before production integration, the
existing resource implementation must be reviewed for any further shared
mechanisms, so synchronous and resumable interpreters do not grow separate
versions of the same policy.

## Waiting and current scheduler limits

`Signal` is a shared atomic revision counter. A waiting operation takes a
revision snapshot **before** checking its condition. If a producer changes the
condition and notifies before the driver parks the task, the changed revision
still makes that task ready. Signal revision exhaustion aborts rather than
silently wrapping. A signal is a wake hint, not a mailbox or a stored result;
the operation must recheck its condition. Cross-thread condition state would
also require synchronization.

`run` and `run_pair` are finite drivers. The pair can hold different machine,
result, error, and capture types without erased storage. It waits for both
tasks; a failure does not automatically cancel the sibling. Tasks use separate
tokens unless the caller deliberately shares one.

When no task can progress, the host sleeps for 1 ms and scans readiness again.
Parked machines themselves are not repeatedly polled. This is sufficient to
validate lifecycle semantics, but adds idle wakeups and timer/cancellation
latency. It is not an OS event loop or a scalability result. The tested scheduler
is single-threaded; only the signal counter and existing cancellation flag use
atomics.

Dynamic spawning, arbitrary heterogeneous task storage, callback registration
and withdrawal, first-completion arbitration, task trees, race semantics,
bounded queues, and OS I/O readiness are not implemented. Nor are a general
`flat_map`/`tail_rec_m` interpreter, arbitrary-depth composition, or scoped
restoration of cancellation with Cats Effect-style `Poll`. The current scope
is a typed composition of three independently resumable components.

## Validation

Qualification passed on Linux x86-64 with **Mojo 1.2.0 (2016d0cd)**, using
`nightly` at `5d9197a36311988019375a0377480ff6b21ecdcf` as the library baseline.
Both `fp` and `state_machine` precompile with warnings treated as errors.

Five clients were checked at O0 and O3 through both source and `.mojoc` imports:
**20/20 checks passed**. The positive client verifies:

- Fair progress, heterogeneous outcomes, parking, notification before parking,
  an already-ready condition, cancellation of a parked task, and timer deadlines.
- 100,000 yields through an iterative driver. This verifies repeated suspension,
  not arbitrary-depth `flat_map` stack safety.
- All 64 combinations of acquisition/body/cleanup failure and cancellation,
  with suspending acquisition and cleanup, exact error order, and exactly-once
  destruction of the owned resource and move-only error payloads.
- Already-canceled scopes and cancellation between acquisition and first use.
- Moving an active task after acquisition, during use, and during cleanup.
- External borrowed captures, successful values, and error payloads.

Four negative clients reject task abandonment, escaping a captured owner's
result, retaining a per-poll resource borrow, and returning that resource borrow
as an independent result. Expected diagnostics are checked; compiler crashes,
timeouts, unrelated failures, and unexpected acceptance are not successes.
Rejection clients are never executed.

Reproduce from the repository root in its pinned Pixi environment:

```sh
pixi run python experiments/async-state-machines/qualify.py \
  --output .cache/async-state-machines-check --jobs 2
```

Use a fresh output directory for every invocation. The local validated bundle
is `.cache/state-machine-foundation/qualification-1/report.json`; it retains
commands, diagnostics, source snapshots, executable hashes, and artifact hashes.
No full-library test suite or performance benchmark was run for this private
experiment. Existing library source is unchanged.

## Next implementation boundary

The accepted [composition and child ownership plan](async-composition-plan.md)
defines the next experiment's interfaces, lifecycle decisions, and acceptance
gates. Its [implementation record](async-composition-implementation.md) describes
the resulting changes and validation.

The next milestone is typed composition and structured task ownership: define
resumable sequencing, iterative loops, and child completion/cancellation before
adding dynamic scheduler storage. Then add callback registration with explicit
completion/cancellation races and a replaceable wakeup strategy. Keep the
lifecycle tests independent of that strategy.

Existing synchronous `ReaderAction.run` endpoints can execute only as bounded
synchronous steps. They cannot suspend transparently. Public integration needs
an explicit resumable endpoint contract and adapters for the existing algebra;
it should not imply that ordinary synchronous calls become asynchronous.

See the [earlier coroutine investigation](async-runtime-investigation.md) for
the capability evidence that preceded this selection.
