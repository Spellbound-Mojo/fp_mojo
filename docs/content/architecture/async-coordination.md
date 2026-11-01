# Resumable coordination

`fp.effects.async_runtime` provides `Deferred`, bounded `Queue`, and `Semaphore`.
Their operations return `IO` values that lift private leaves over the
[wake-driven scheduler](async-scheduler.md). Their pure-Mojo
implementation reuses the canonical synchronous coordination state transitions.

## Shared execution

Canonical `fp.effects.coordination.Ref` still owns state transitions, callable
invocation, exact error capture, unlocking, and cancellation settlement. Its
private action boundary separates guard acquisition from execution under that
guard. Synchronous IO retains its existing cancelable lock wait. A resumable
operation attempts the same guard once per poll and yields on contention.
No async operation holds the state guard across suspension.

Each Ref also owns a change event. Mutation notifications happen after unlocking;
observation does not notify. A waiting adapter captures the event revision before
inspecting state. Registration rechecks that revision, covering notification
between the state observation and parking. Slot-owned subscriptions disappear
when the operation resumes or completes.

The adapters call the existing Deferred, Queue, and Semaphore factories and
reuse their exact transition types. They suppress notifications for unsuccessful
waiting attempts: two takers on an empty queue, or two offerers on a full queue,
must not continually wake one another. Successful queue transfers notify other
waiters. Explicit one-attempt operations may issue a harmless extra notification.
Canonical Permit destruction also notifies through its existing Ref update.

## Operation contracts

| Type | Operations | Ownership and waiting |
| --- | --- | --- |
| `Deferred[T]` | `complete[E]`, `try_get[E]`, `get[E]` | Single assignment; `T` must be copyable. Each successful reader receives one owned copy. |
| `Queue[T](capacity)` | `size[E]`, `try_offer[E]`, `offer[E]`, `try_take[E]`, `take[E]` | Positive capacity, FIFO buffered values, move-only payloads supported. A waiting offer retains its rejected input. |
| `Semaphore(permits)` | `available[E]`, `acquire[E]`, `with_permit(program)` | Nonnegative initial count; acquisition yields the canonical move-only `Permit`. |

Queue and Semaphore construction delegate validation to the synchronous types.
Methods build unentered `IO` values, which may be dropped normally. Entered
work belongs to a linear `Task` or `Driver` and must drain. All values, captures,
and errors retain their native types and origins. The async names are part of
the opt-in public preview; synchronous operations keep their existing contracts.

Cancellation before a transition leaves shared state intact. A committed enqueue
or dequeue survives late cancellation. A dequeued result that is suppressed by
cancellation is destroyed, without rolling the queue back. A suppressed permit
is destroyed only after unlocking, so restoring its count can safely reenter the
same Ref. Unopened or canceled waiting offers destroy their retained input once.

`with_permit` acquires **outside** the resource scope, where the wait remains
cancelable. An `IO` bind transfers the acquired owner into a scope before entering
the body. Cancellation at the handoff drops the unentered permit owner. Once
the body is entered, the scope retains its permit through every body suspension
and through the body's cancellation cleanup. Scope completion releases the
permit on success, failure, or cancellation.

The driver bounds scheduling operations, not instructions inside user code or
destructors. Canonical Ref callbacks and payload destruction are synchronous;
they must not block or reenter a state guard they already hold. Permit destruction
uses the existing synchronous release path. The supported boundary is cooperative
single-thread execution, not contention between parallel execution threads.
FIFO buffered values and FIFO scheduler readiness do not imply FIFO waiter
fairness: notification makes waiters eligible, and the host controls root order.

## Validation

Deterministic clients cover 16 waiting readers, duplicate completion, full and
empty queues with multiple waiters, idle poll counts, guard-contention budgets,
cancelable permit acquisition, and permits retained during suspended callback
withdrawal. Ownership tests cancel immediately after canonical enqueue, dequeue,
and reservation transitions; check exact destruction and reader-copy counts;
and exercise exact move-only observation errors. Native-origin clients preserve
borrowed values and errors. Compiler rejection fixtures reject move-only Deferred
payloads and escaped Queue/Deferred origins.

The qualification runner includes these clients alongside the previous scheduler,
composition, fiber, callback, and resource tests, plus nine synchronous IO,
resource, coordination, and fiber regression clients. Every client is checked
through source and separate-package imports at O0 and O3, with warnings as errors.
The three iterative/deep clients also run under a 1024 KiB stack limit.

From the repository root in the pinned Mojo environment:

```sh
pixi run python experiments/async-state-machines/qualify.py \
  --output .cache/async-coordination-check --jobs 2
```

Use a fresh output directory. OS parking and readiness integration remains
subject to the [public Mojo platform findings](async-scheduler.md#public-platform-boundary).

The [overnight results](async-qualification.md#overnight-results) cover sustained
queue and semaphore reuse, registration retirement, restored permits and bounded
retained storage across repeated structured worker cycles.
