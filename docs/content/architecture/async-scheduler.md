# Wake-driven execution

The canonical wake registry and async driver implement cooperative scheduling
for `fp.effects.async_runtime`. `Driver(program, token, clock)` owns a linear task and
`poll(budget)` returns `Progress`: completion, runnable status, the earliest
live deadline, and the number of root polls and timer events performed.
`finish()` still requires complete draining. `Clock.manual()` and `advance_to()`
allow deterministic host control; default clocks use public monotonic time.

## Registries and tasks

Every task, the root program and each fiber, owns a wake registry
(`_Runtime` in `src/fp/_internal/waking.mojo`): a tree of generation-checked
nodes behind one lock, one node per execution slot of that task, so wakes for
different tasks never contend. A node's own readiness is distinct from its
ready descendants. This distinction matters when a child starts and parks
during one enclosing poll: consuming that child's wake must also clear
inherited ancestor readiness without losing an independent notification. Ready
siblings use intrusive FIFO links; removal is O(1), and duplicate notifications
retain the existing queue position.

The registry's root wake hook schedules its task when the root's ready list
becomes non-empty: an idle task becomes scheduled and is queued, and a running
task becomes notified. The hook runs under the registry's lock, and a run that
ends decides under the same lock whether the task is requeued or idle, so a wake
from any thread is either seen by that decision or finds the task idle. Every
atomic operation on the scheduling state documents its ordering in the source:
the hook's compare-and-swap is acquire-release, parking stores with release,
and the queue's lock orders a task's body between runs.

Signal subscribers retain only metadata handles. Task generation and wait epoch
checks reject both notifications for retired storage and notifications from a
previous wait on the same live task. Registration compares the captured revision
under the signal guard. Subscriptions are removed on polling and completion.
The shared cancellation token emits the same notification on its first request;
its atomic requested flag remains the source of cancellation state.

## The current-thread executor

All registries under one root share a scheduler: the ready queue, the timer
heap, the host notifier, the atomic count of live external registrations, and
the lock-free diagnostic slots of live fibers. The
current-thread executor (`src/fp/effects/_async/executor.mojo`) runs the
root's tasks on the thread that polls it. The transition slice belongs to the
executor and reaches each task it runs through the task's context; the
thresholds and the reporter beside it are read-only. One root poll is one
executor turn: it refills the slice, then runs queued tasks in FIFO order, each at
most once, until the budget is spent, the queue is empty, or the next task
already ran in this turn. Idle tasks cost nothing: a parked fiber is never
scanned or entered until a wake queues it.

The ready queue is a lock-guarded deque behind a small interface (`_TaskQueue`)
that a work-stealing worker's local ring and external queue can implement. A
queue entry is the right to run a task, and only the executor holding it
touches the task's body, so moving entries between workers moves that right.

Timers use the standard library `BinaryHeap`, shared by the root's registries.
An entry names its registry node and wait epoch; stale entries are discarded
before reporting a deadline, and the heap is rebuilt when it holds more than
twice the live timer count plus 32. Node and subscriber storage is reused and
bounded by peak simultaneous registrations. Registries never store computation;
task bodies are owned by their tasks.

## Driver bounds

The nonblocking driver never calls the host-idle helper. Its budget limits root
polls plus timer events and alternates ready work with due timers. User polls,
notification fanout, and heap maintenance are not preempted or bounded by an
instruction count. All clocks propagate through masks and child contexts.

The public `run` polls the driver while work is runnable and otherwise parks
in the root's poller (`Driver.park`, below); only the internal test helper
`run_pair`, which drives two roots that cannot share one park, keeps a 1 ms
idle sleep. A host can instead call `poll` after its own event delivery and
use the reported deadline, call `park` itself, or give `Driver` a notifier, an
erased repeatable callable called when an event delivered while no poll runs
makes the root runnable. The notifier is called only when the ready queue was
empty and no poll is running; a poll clears its polling flag before reading
readiness, both sequentially consistent with the queue, so either the poll
reports the work or the notifier runs. `finish` stops notifications and waits
for a call in progress.

## Root parking and the wake hook

The root parking system and wake hook operate on the polling architecture below:

- **The root's poller.** A root owns one `_Poller`, created on its first park
  or descriptor wait and destroyed by `finish`, so a root that never parks
  opens no pipe. Its address lives in a scheduler word that only the driving
  thread touches.
- **The wake hook.** Creating the poller installs its interrupt as the
  scheduler's `_WakeHook`, an address and a thin function, because the poller
  lives above `fp._internal.waking`. When a wake makes the root runnable while
  no poll runs (`_Scheduler.push` found the queue empty and the polling flag
  clear), `notify_host` fires the hook and then calls the host notifier, if
  one is installed. Both are guarded by the same notify-or-close handshake,
  so neither runs after `finish` returns.
- **`Driver.park(timeout)`** returns at once when the root is completed or
  runnable, or a deadline is due. Otherwise it waits in the poller until the
  earliest deadline (on the driver's clock), an interrupt, a ready descriptor,
  or the host's timeout. `run` is `poll(64)` until completed, with `park(None)`
  whenever the root is not runnable, so an idle program uses no CPU and a timer
  fires when `poll()` returns, under 1 ms after its deadline.
- **The lost-wake handshake.** A waker publishes the task under the ready
  queue's lock, then fires the hook, which interrupts the poller. `park`
  installs the hook, re-reads the queue under the same lock, and only then
  polls. If the push came first, the re-read finds the task. Otherwise the
  hook's RELEASE store happens before the waker's ACQUIRE load, so the waker
  interrupts, and the poller's own handshake (publish, interrupt; drain,
  clear, re-check) makes the poll return. The caller then polls the driver,
  which is the re-check. `run_parks` and `foreign_completion` race wakes from
  OS threads against parks.
- **Readiness found by a park** is notified with the polling flag set, so it
  neither interrupts the poller again nor calls the host notifier: the parked
  host polls next. `Driver.poll` checks the poller without waiting
  (`poll(0)`) at its start whenever a descriptor is armed, also with the flag
  set, so a host that never parks, and `TestControl`, still observe readiness.
- **Descriptor waits.** `await_readable[E](fd)` and `await_writable[E](fd)`
  lift `_AwaitDescriptor` (`fp.effects._async.descriptors`). Its first poll
  registers with the root's poller and a fresh `Signal`, and suspends with
  `Wait.changed`. A later poll reports readiness, hang-up and errors
  included, once, and removes the registration. A canceled poll removes it
  too. On the work-stealing pool the wait registers with the running
  worker's own poller instead (see
  [timers and descriptors per worker](#timers-and-descriptors-per-worker)).

### The scheduler's words

The scheduler's cross-thread atomics live in one 64-byte-aligned allocation
(`_SchedulerWords`), reached through a `Pointer[..., MutUntrackedOrigin]` and
only through immutable `self`. The scheduler is held by `ArcPointer`, so the
words live as long as it does. `in_flight` and `registrations`, which foreign
threads write, each have their own line; the rest share the third.

| Word | Written by | Ordering |
|---|---|---|
| `polling` | Driving thread | SEQUENTIAL store and load, paired with the queue (`push`, `Driver.poll`) |
| `closed`, `in_flight` | `close`; every waker | SEQUENTIAL on both sides of notify-or-close; RELEASE decrement after a call |
| `live_timers` | Registries | RELAXED; a heuristic bound on heap tombstones |
| `registrations` | Callbacks, on any thread | RELEASE increment and decrement, ACQUIRE load (`_Registrations`, which holds the scheduler) |
| `blocking` | Driving thread | The blocking pool's install and take (`blocking_pool.mojo`) |
| `poller` | Driving thread only | RELAXED |
| `wake_target` | Driving thread, once | RELEASE store after writing the hook's function; ACQUIRE load in `notify_host` |
| `notifier` | Before the root is shared | Plain; cleared by `shutdown` after `close` |

These fields share a single unified allocation for the root state, avoiding
multiple small pointer allocations.

### The cancellation bridge

`CancellationToken._wake_on_cancel(hook)` subscribes a `_WakeHook` to the
token's signal. `Signal.notify` fires hook subscriptions under the signal's
lock, which a hook may take because it takes no lock itself, so a hook never
fires after its subscription is dropped, which takes the same lock; a token
already canceled fires it at once. The one interruptible wait loop,
`_park_interruptibly` in `_io_core.mojo`, serves `Interruption`'s `sleep`,
`await_readable` and `await_writable`, and `sleep_io`. On a blocking-pool
worker it waits in the worker's poller, which the pool interrupts when the
call is withdrawn. Inline, as in `SyncIO`, it waits in a fresh poller that the
bridge interrupts, so a request made during the wait ends it at once. A
masked `sleep_io` sleeps its whole duration without a poller. `syncio_waits`
covers each case.

## Public platform boundary

The pinned Mojo **1.2.0 (2016d0cd)** standard-library sources were inspected at
the `mojo/v1.2.0` tag. Their public interfaces do not supply the parking/readiness
boundary needed here:

- [`std.net`](https://github.com/modular/modular/blob/mojo/v1.2.0/Mojo/stdlib/std/net/__init__.mojo)
  explicitly says its public types are not yet available.
- [`std.runtime`](https://github.com/modular/modular/blob/mojo/v1.2.0/Mojo/stdlib/std/runtime/__init__.mojo)
  exports runtime initialization and parallelism queries, and explicitly keeps
  unfinished async primitives private.
- [`Atomic`](https://github.com/modular/modular/blob/mojo/v1.2.0/Mojo/stdlib/std/atomic/atomic.mojo)
  provides atomic operations but no host wait/notify method.
- [`FileDescriptor`](https://github.com/modular/modular/blob/mojo/v1.2.0/Mojo/stdlib/std/io/file_descriptor.mojo)
  exposes reads/writes but no readiness registration.
- [`std.time`](https://github.com/modular/modular/blob/mojo/v1.2.0/Mojo/stdlib/std/time/time.mojo)
  supplies monotonic time and timed sleep, which does not provide notification
  driven interruption.

Bounded compiler probes under `experiments/async-state-machines/platform/`
confirm public clock/sleep availability and reject `Atomic.wait` and a public
`Socket` import. Those two rejection probes verify specific missing interfaces;
they are not a proof about every possible library representation. The inspected
tree and raw probe results are retained under `.cache/scheduler-investigation/`.
No C backend, direct foreign-function boundary, private coroutine dependency,
or compiler/stdlib change was added. The nonblocking host boundary is usable
independently of a future parking backend.

## Qualification

Maintained clients cover notification ordering, FIFO budgets, stale task and
wait generations, timer replacement, checked time arithmetic, linear-driver
ownership, masked cleanup and parked fibers. The runner checks source
and separate-package imports at O0/O3 with warnings as errors and retains raw
compiler/execution evidence.

The [overnight qualification](async-qualification.md) confirms sustained registry
and subscription reuse, bounded timer tombstones and retired registrations.
Its separate performance client verifies zero child polls during idle driving
with 1, 64 and 512 sleeping children. These results do not qualify a public
network backend or cross-thread task execution.

## Blocking pool

`IO.blocking` and `IO.interruptible` run on a blocking pool
(`src/fp/effects/_async/scheduling/blocking_pool.mojo`), after Cats Effect's
blocking execution context and Erlang's dirty I/O schedulers. Neither touches
a run loop from another thread: a call is an `IO.async` registration
(`src/fp/effects/_async/blocking.mojo`) whose register function queues an
erased job, and the worker completes the registration's `Completion`, so only
`Completion`'s qualified cross-thread behavior carries the result back.
`blocking` registers inside a masked region; `interruptible` registers
unmasked, and its withdrawal, which runs masked after every entered
registration, cancels the call's token and waits for the worker to report that
the function returned.

- **Queue.** The striped `_ExternalQueue` holds the jobs; workers and
  submitters pop and push under stripe locks.
- **Claims.** Idle workers sit on a locked idle list; a submitter takes one
  and interrupts its poller (see below).
- **Spawning and retiring.** A submitter that claimed no worker starts one,
  below `max_workers`, under the worker-list lock. A worker whose idle timeout
  passes re-reads the queue under the same lock before exiting, so a job is
  never left without a worker.
- **Ownership.** The root's `_Scheduler` holds one word: zero, or the address
  of the root's pool and in-flight count. A configured pool is installed when
  the root is created; otherwise the first blocking call builds a private pool
  and installs it with one compare-exchange from zero (acquire-release; a loser
  drops its threadless candidate). The worker decrements the in-flight count
  with release ordering after its last use of the job; `finish` takes the
  word, waits for the count with acquire loads, then drops the root's copy,
  and does nothing more for a root whose word is still zero. Each worker body holds the pool's core until it returns,
  and the worker list holds none, so a pool closed on its own worker detaches
  that worker, which releases the core last.

Each worker owns a `_Poller` and parks in `poll(idle_timeout)`. An idle
worker publishes its `_Interrupter` on a locked idle list before re-reading
the queue, and a submitter pushes its job, then claims one entry and
interrupts it; both pass through the idle list's lock, so no job is missed.
An interruptible call lends its worker's poller to its `Interruption`, and
every wait made through the handle subscribes the token's bridge
(`_wake_on_cancel`) for its duration, so the withdrawal's request (canceling
the call's token) wakes `Interruption.sleep` and its descriptor waits. This
one mechanism, rather than a direct interrupt of the worker, ends every
interruptible wait on both profiles. A descriptor wait registers
in the poller on the worker's own thread and deregisters before it returns. The
`blocking_pool` client checks other fibers running during a call, results and
errors, timeouts that wait, interruption, a sleep through the handle woken by
the request, reuse and retirement against the process's thread count, idle
workers using almost no CPU, the maximum under a burst, payload destruction exactly
once, root finish, shared pools, and the last copy dropped on a worker.

## Work-stealing structures

The concurrent structures of the work-stealing pool reside in the private
package `fp.effects._async.scheduling`. Each module documents the memory ordering
of every atomic operation and why it suffices. Elements are generic move-only
values, and each one leaves a structure exactly once or is destroyed with it.

- **Local ring** (`_LocalQueue`), after Cats Effect's `LocalQueue`: a fixed
  ring with one producer and many consumers, 256 entries and batches of 32 by
  default. Its head word packs a steal tag and a real tag, which are 32-bit
  rather than upstream's 16-bit, so a thief claims half the elements by
  advancing the real tag and releases them by advancing the steal tag. A full
  ring moves half its elements to the external queue in batches.
- **External queue** (`_ExternalQueue`), after `ScalQueue`: power-of-two
  stripes stored inline, each a standard-library `Deque` with its lock and a
  published length, so consumers skip empty stripes without locking. Stripes
  are locked through `_lock_cell` in `fp._internal.cells`, a borrowed guard that
  shares its acquire and release with `_lock_metadata`, costs no reference
  counting, and spins up to 256 times before yielding. Upstream offers each
  32-element spill batch as one element to a random stripe and moves a polled
  batch into the ring in one step. Here each batch goes to its own random
  stripe as separate elements, and a refill takes up to one batch from one
  stripe.
- **Timer heap** (`_TimerHeap`), after `TimerHeap`: changed only by its owner.
  Any thread may cancel through a generation-checked ticket (the wake
  registry's `_Ticket`), which marks and counts the node; the owner packs once
  counted cancellations reach half the heap. Other workers take expired timers
  by walking the heap, after reading an earliest-deadline hint kept on its own
  cache line. Upstream clears callbacks with plain writes and tolerates a
  duplicate run. Here a single compare-exchange on each node's state word
  picks the one taker of a move-only payload. Slots, payloads and heap entries
  live in chunks that never move, so no reclamation scheme is needed.
- **Parking** (`_Parking`), after `WorkStealingThreadPool`: the state machine
  only, since the operating-system park and unpark belong to the poller. One
  word counts active and searching workers. Searching is granted only while
  fewer than half the workers search, enforced exactly by compare-exchange.
  Submitters wake a parked worker only when none is searching and fewer than
  all are active. A per-worker parked flag claimed by compare-exchange makes
  exactly one notifier unpark a worker for one parking. Sequentially
  consistent fences on the submitter's and the last parking searcher's paths
  ensure that one of them sees the other, so no work is stranded. A worker
  waits out a notifier's claim of its flag before it publishes PARKED: a
  thread a notifier started runs before the notifier's `finish_unpark`, and
  a first park in that gap is waited out to prevent lost counts.

Cross-thread operations borrow a structure immutably and change only atomics
and the slots they have claimed. Mojo cannot express a victim and an exclusive
destination borrowed from the same collection, so `steal_into` relies on the
protocol rather than the borrow for `dst`.

The clients `wstp_queues`, `wstp_timers` and `wstp_parking` check exact
single-thread contracts, then run several threads with tracked elements to
prove that each element is received at most once (exactly once when drained)
and destroyed once, including leftovers. `wstp_parking` runs workers on
`OSThread`s with a test-only self-pipe parker. It submits work after every
worker has parked, checks the searcher bound, and checks for one unpark per
parking. It fails when the last searcher's re-check is removed. Measurements
from `probes/wstp_cost.mojo` at O3 on a 4-core x86 host:

| Operation | ns |
|---|---|
| Acquire load, release store, relaxed load (plain-load cost) | 0.4–0.7 |
| `fetch_add`, compare-exchange, sequential store, sequential fence | 6–9 |
| Ring enqueue and dequeue pair | 14 |
| Stolen element, or element spilled to the external queue | 15–19 |
| External push and pop pair (`_lock_cell`; 75–81 with `_lock_metadata`) | 31–33 |
| The same pair under a hand-written borrowed spin lock | 25 |
| Timer insert and poll with 1,000 timers queued (`BinaryHeap`: 45–60) | 56–61 |
| Timer insert and owner cancellation, or marked cancellation | 22–37 |

Under contention, an owner's ring pair costs about 350 ns while two thieves
steal in a tight loop. An external pair costs 1.1 µs with four threads on four
stripes (1.5–1.6 µs with `_lock_metadata`). That cost is mostly cache-line
transfer: yielding after every failed attempt costs 10–25% more than spinning
without yielding, and 256 spins match spinning. A timer insert and poll costs
230–300 ns while two threads steal due timers, against 410–460 ns before the
earliest-deadline hint moved to its own line.

## The work-stealing pool

The work-stealing pool runs fibers in parallel across a pool of workers, following
Cats Effect's `WorkStealingThreadPool` and `WorkerThread`, in the private module
`fp.effects._async.pool`. It represents the work-stealing profile; the current-thread
executor above is the alternative profile (see [selecting the profile](#selecting-the-profile)).
Both profiles run the same tasks, wake registries, fibers, ownership scopes, and
run paths (`_Executor.run_body` and `settle`). They differ only in where a woken
task is queued and who executes it.

### Shape

- **Workers.** A pool has one worker per logical processor by default. Each
  worker has a local ring (`_LocalQueue`) and its own poller, in which it
  parks. The pool has one external queue and the parking state machine
  (`_Parking`). Per-worker state lives in one allocation of padded slots,
  reached only through untracked pointers, and the pool itself only through
  immutable `self`.
- **Worker 0 can be the caller.** `_run_pooled` runs the root on the calling
  thread as worker 0. Workers not yet started count as parked, with a
  NOT_STARTED flag, and a notifier that claims one starts its thread instead
  of unparking it. A program that never makes work to steal starts no
  thread, so a per-call `run` pays for no thread start. `start_all` starts every
  worker at once, for a runtime whose caller only waits (`_RootHandle.wait`).
- **A start that fails** is not an error. Notifiers run on any thread,
  inside wake paths that cannot raise. If `pthread_create` fails, the
  claimed worker is uncounted and marked not started again
  (`_Parking.start_failed`), and the failure is counted (`failed_starts`).
  The work stays queued, where a running worker finds it; on a per-call run,
  worker 0, the caller, always runs. A later notifier may try again.
- **The root is an ordinary task.** Its body owns the root slot and context,
  so any worker may run it. Its completion publishes the outcome and wakes
  whoever waits for it, through a two-word handshake (`_RootDone`).
- **The current worker** is named by a pthread key per pool (`ThreadKey` in
  `fp._internal.os`), as Cats Effect asks whether the current thread is one
  of its pool's workers.

### Wakes

A root's scheduler reaches its pool through `_Dispatch`: an address and thin
functions, like the poller's `_WakeHook`, because `waking.mojo` sits below
the pool.

- **Where a woken task goes.** On one of the pool's workers it goes onto
  that worker's ring; from any other thread, onto the external queue.
- **Waking a worker.** After the registry lock is released, `notify` wakes a
  parked worker, or starts one, when no worker is searching and not all are
  active.
- **A wake from the running task** goes into the worker's LIFO slot
  (below), which needs no notify.
- **A push onto the worker's own ring** notifies only when the ring then
  holds more than one entry. Otherwise the worker runs that entry next
  itself.
- **A wake while the task runs** marks it notified, and the end of the run
  requeues it (`_Runtime.park`), as on the current-thread profile.
- **Foreign wakes.** A wake from a thread outside the pool is two dispatch
  calls, a push and then a notify. It may arrive after its root completed,
  for example a late `Completion` or a `BlockingPool` worker finishing late,
  or the task it woke may run and its root complete between the two. So such
  a wake enters the root scheduler's notify-or-close handshake
  (`in_flight` and `closed`, above) in `push` and leaves it at the end of
  `notify_host`. The root closes its scheduler, which waits for wakes in
  flight, before its pool shuts down, and a closed scheduler drops a later
  push. A push from one of the pool's own workers takes no handshake: a
  running worker keeps the pool alive, so no word of the root is written by
  every wake. `wstp_wakes` found the use-after-free this prevents.

### The worker loop

`run_worker`, after `WorkerThread.run`, first takes the task in its LIFO slot,
within the slot's bound (below). Otherwise:

1. Every 61st iteration, take a batch from the external queue first and fire
   due timers.
2. Take from its own ring.
3. Take a batch from the external queue.
4. With permission to search (at most half the workers search), fire other
   workers' expired timers, then steal half of a victim's ring, each scanning
   from a random worker.
5. Otherwise fire its own due timers and check its armed descriptors without
   waiting. If nothing woke, park in its own poller until its own next
   deadline.

A worker counts itself active and searching after any wake, whether a
notifier woke it or a deadline, shutdown, its root or a spurious interrupt
did. The last parking searcher re-checks every queue (`_Parking`'s
handshake). A one-worker pool's sole worker still takes permission to search,
which is never refused to it, though it has no one to steal from: a
non-searcher parks without the re-check, which is safe only while some
searcher exists.

**Fairness.** Each task run gets its own transition slice, Cats Effect's
per-fiber auto-yield. On the pool every fiber owns a `_Budget` slice
(`_Budget.slice`), made when it is admitted and refilled whenever a worker
runs it. The refill is `_TaskRun`'s flag: the executor's `begin_run` hook.
One task runs on one worker at a time, so no slice is ever shared. The
current-thread executor keeps one slice per turn, shared by every task in
that turn.

### LIFO slot

Following the design of Tokio's `lifo_slot`, each worker provides a single-task
LIFO slot for immediate hand-offs. This avoids cross-thread stealing latency for
tightly coupled producer-consumer transitions: when a task yields or wakes its
successor, the next task runs immediately on the current worker thread without
incurring ring insertion and thread unpark overhead.

- **One slot per worker,** an `Optional` entry in the owner line of
  `_WorkerSlot`, beside a count of consecutive runs from it (`lifo_runs`).
  Only the worker's own thread touches either, as only it pushes onto its
  ring. Stealers never see the slot.
- **What goes in.** A task woken by the task the worker is running
  (`_pool_push` while `running` is set) goes into the slot, and the slot's
  previous occupant moves to the back of the ring. Every other push keeps
  the ring path above: the end of a run requeueing its own task (a wake
  during the run, or an exhausted slice), timers the worker fires, and
  external batches. So a task that yields still goes to the back of the
  ring, not ahead of it.
- **Notification.** Filling an empty slot never notifies: the worker runs
  that task next. A displaced occupant notifies under the ring's rule for a
  worker that is not running a task, that is, only when the ring then holds
  more than one entry. Tokio notifies on every displacement. Here that kept
  one cross-worker wake in every fiber pair, because starting the second
  child displaces the first, and the pair stayed at the old cost. A fan-out
  still notifies from its third start on.
- **The displaced task's latency bound.** A displaced task left on a busy
  worker's ring without a notify can be stolen at once by any worker that is
  active or searching. A parked worker learns of it by the end of the
  running task's run at the latest, which its transition slice bounds. The
  run then ends, and either the worker takes the entry itself or its own
  requeue makes a second ring entry, which notifies. `wstp_lifo` measures
  this. With every other worker parked, a root displaces a fiber and keeps
  running short steps, and a parked worker steals the fiber after 509 of
  them, which is one 1024-transition slice. Only user code that blocks the
  thread stretches the bound, and it delays the ring's other entries as
  much.
- **The bound.** At the top of every iteration the worker takes the slot's
  task before `_find`, at most `_MAX_LIFO_RUNS` (3, Tokio's
  `MAX_LIFO_POLLS_PER_TICK`) times in a row. A fourth occupant goes to the
  back of the ring, and the worker looks for work as usual. Every trip
  through `_find` resets the count. Two fibers that keep waking each other
  therefore let the ring's head run after every three slot runs.
- **Flushes.** `_flush_lifo` moves the occupant to the back of the ring,
  notifying under the same rule. The worker calls it before parking and when
  it leaves its loop, so no task waits in the slot of a worker that is not
  running. The slot is already empty at the park, since the worker checks it
  before it looks for work; the call keeps the rule explicit. Shutdown's
  drain (`drain_on_shutdown`) then sees only the ring.
- **The blocking hand-off.** The slot lives in `_WorkerSlot` with the
  ring, so it moves with the ring to the replacement thread that takes over
  the slot. A retired worker does not flush at exit, because its slot
  belongs to the replacement by then. A hand-off that moved the ring's
  entries elsewhere would call `_flush_lifo` first.

**Fairness and stealing.** A task in a busy worker's slot is invisible to
idle workers until the current run ends. Tokio accepts this, and so does
the pool. The wait is bounded by the running task's transition slice, unless
user code blocks the thread, which delays the ring's entries just as much.
After that the slot's task runs next, or, past the bound, joins the ring,
where any worker can steal it. Nothing waits in the slot of a parked worker.

**Lost wakes.** Only the slot's owner fills it, and only while it runs a
task. The owner checks the slot at the top of its next iteration, before it
could search or park. `wstp_lifo` checks the rules: a ping-pong pair on
one worker leaves a ceding fiber on the ring at most `2 × (3 + 2)` hops
between steps; the slot's task runs on its waker's thread after the waker's
run, while stealers take the ring around it; the flushes; and runs of fiber
pairs and the ping-pong pair on four workers without a lost wake. It also
checks that a parked worker takes a displaced fiber within half of a busy
root's 20,000 steps, and on another thread.

**Measurements.** O3, on this 4-core host, built back to back with the
previous build, before the slot; each figure is the median of six rounds,
with the range in brackets.

| Case | Current-thread, before | Pool, before | Current-thread, with the slot | Pool, with the slot |
|---|---|---|---|---|
| Trivial `run()` | 2.81 µs [2.70–2.88] | 3.64 µs [3.56–3.80] | 2.79 µs [2.33–2.86] | 3.41 µs [3.01–4.10] |
| Fiber pair, no yields | 9.70 µs [9.35–9.97] | 23.3 µs [23.0–24.7] | 9.85 µs [8.80–10.4] | 9.53 µs [8.95–9.89] |
| Foreign completion round trip | 7.83 µs [6.37–8.06] | 7.74 µs [6.25–8.13] | 7.94 µs [7.41–8.11] | 7.94 µs [7.27–8.40] |
| Join racing a completion | 5.92 µs [5.79–6.01] | 17.8 µs [17.0–18.4] | 5.84 µs [5.76–5.98] | 6.00 µs [5.75–6.04] |
| IO loop step | 38 ns | 39 ns | 39 ns | 38 ns |

- **The pool's fiber pair and join match the current-thread profile**,
  fulfilling the parity requirement for default pool scheduling.
- **The current-thread profile is unchanged**: the slot is pool code.
- **Pairs that cede** still cost more on the pool (about 27 µs, against 42 µs
  before): a ceding run requeues onto the ring, where a second entry
  notifies another worker.
- **Parallel speedup** remains strong: 1.92× on two workers and 3.55–3.75×
  on four workers.

### Worker architecture

Named methods on the pool and worker coordinate task dispatch and lifecycles:

| Hook | Purpose | Contract | Implementation |
|---|---|---|---|
| `fire_timers(now) -> Int`, `next_deadline()`, and `push_timer` | Timers | Run on the worker's own thread. Woken tasks land on its ring. The deadline is the park timeout. | A dedicated timer heap per worker ([below](#timers-and-descriptors-per-worker)). |
| `_current_worker(scheduler)`, `_WorkerRef.hand_off_for_blocking(job)`, `retired` flag | Blocking hand-off | A worker that took a blocking call during a run leaves its loop when the run ends, hands its slot to a replacement thread, and runs the call. | See [Blocking hand-off](#blocking-hand-off). |
| `shutdown()`, `shutdown_on_worker()`, `closing()`, `drain_on_shutdown()` | Shutdown | Called once by the pool's owner. Waits for foreign wakes, claims workers never started, interrupts remaining workers, and joins them. | See [the runtime](#the-runtime). |

### Timers and descriptors per worker

Every worker maintains its own timer heap and places descriptor waits on its
own poller, following Cats Effect's `TimerHeap` and per-worker `PollingSystem`.
The current-thread profile keeps the root's heap and poller, and `TestControl`
runs on it with a manual virtual clock.

**Timers.** Each worker owns one `_TimerHeap` of `_Waker`s, in a per-pool
array apart from the worker slots. Only the owner inserts, fires and
restructures it.

- **Arming.** `_Runtime.arm` runs during a task run, on a worker. Under the
  registry's lock, it inserts the deadline into the running worker's heap
  through `_Dispatch.timer` (`_Scheduler.start_timer`) and stores the
  returned handle, the worker and the heap's ticket, in the registry node.
  The insert takes no lock and runs no waker, so holding the registry's lock
  is safe; the lock is also what later hands the ticket to another thread.
  Arming off the pool's workers aborts: only task runs arm deadlines.
- **Cancellation.** A registration clears its deadline when it is polled
  again, retired or fired. Clearing calls `_Dispatch.cancel_timer` under the
  same lock. On the owning worker, `cancel_owned` removes the node at once.
  From any other thread, `cancel` marks the node and counts it, and the owner
  removes marked nodes once the count reaches half its heap
  (`pack_if_needed`, run on every insert and whenever it fires timers).
  Firing forgets the handle without cancelling.
- **Firing.** `fire_timers` pops the owner's due timers and fires each after
  the heap call returns, so no heap operation is in progress while a waker
  runs. Woken tasks land on the owner's ring. `next_deadline`, the heap's
  root, is the worker's park timeout.
- **Stealing.** A searching worker reads each other heap's earliest-deadline
  hint, walks the heaps with expired roots from a random worker, and takes up
  to 32 timers (`steal_into`), which it fires on its own thread. Cats Effect
  checks timers before queues while searching, and so does `_find`.
- **Staleness.** The wake registry's epoch and generation checks decide, under
  its lock, whether a fired or stolen waker still owns its deadline. A thief
  whose claim raced the owner's cancellation finds the deadline cleared and
  does nothing.
- **No shared count.** On the pool the root's live-timer count, a heuristic
  for the current-thread heap's rebuild, is not kept, which removes a
  read-modify-write on a word shared by every worker from every arm and clear.
- **Teardown.** The pool's destructor takes every pending timer out first,
  since a pending timer keeps its registry and task alive. It then destroys
  the rings, then the heaps and the pollers, so a task destroyed with a ring
  can still cancel into any heap and release in any poller.

**Descriptors.** On the pool, `_AwaitDescriptor` registers with the running
worker's poller, opened on first use. Readiness notifies the wait's `Signal`,
whose subscription wakes the fiber like any other wake, so the fiber may then
run on another worker. A worker checks its poller without waiting whenever it
fires its timers and has armed registrations, so a busy worker still reports
readiness, as Cats Effect's worker polls every 61 iterations.

Finishing or dropping the wait on its poller's owner reads readiness and
removes the registration as before. Anywhere else it calls
`_release_registration`, the poller's only cross-thread operation besides
interrupts:

| Word | Ordering |
|---|---|
| A registration's word, `generation << 3 \| state`, in `_StableChunks` (chunks that never move) | The owner stores (generation, ARMED) RELEASE when it registers. The owner claims ARMED to FIRED, and ARMED to SHUT when closing, with RELAXED compare-exchanges. A failed claim means a release won, and the registration is removed without being notified. |
| The same word, from another thread | `_release_registration` loads it ACQUIRE and, while its generation matches, sets the released bit with an ACQUIRE_RELEASE compare-exchange. It returns whether the registration had fired or closed, which is what the owner's `readiness` would have reported. |
| The poller's `released` count, on its own line | Incremented RELEASE after a successful release. The owner loads it ACQUIRE at the top of every poll and, once it exceeds the releases it has accounted for, sweeps the released words. |
| Removal | The owner frees an entry by compare-exchanging its word to the next generation and FREE (ACQUIRE). This sees a release that raced it, and a later release carries the old generation and fails. |

A release of a registration that was still armed also interrupts the owner,
whose next poll then stops watching a descriptor that the caller may now
close. Linux keeps a polled file open until `poll` returns. Releases must
happen before their pool is destroyed, which holds because a descriptor wait
finishes or is dropped in a task run before its root completes.

**Qualification.** `wstp_worker_timers` runs on four-worker pools:

- sleeps across workers, none early, ending on more than one worker;
- their lateness, whose median and 90th percentile must stay under 1.5 ms;
- timeouts that cancel 10 s timers, with cancellations from other threads
  counted by the heaps;
- the largest heap a worker owns while churning, and every heap holding no
  pending timer after its run, then emptying;
- expired timers fired by searching workers while their owners spin
  (`stolen_timers`);
- descriptor waits on per-worker pipes that half lose to a timeout, with
  registrations released from other threads, then all removed;
- a root canceled from a foreign OS thread while it sleeps 30 s.

`descriptor_readiness`, `instant_timers`, `timeouts` and `run_parks` joined
`POOL_CLIENTS`, so their `run` parts also run on the pool.

**Measurements** for the performance gates, which allow no regression beyond
run-to-run noise against the previous build: at O3, built back to back with
that build (before) and with per-worker timers and descriptors (after);
medians of six rounds, with the range of round medians in brackets.

| Case | Profile | Before | After |
|---|---|---|---|
| Trivial `run()` | Current-thread | 3.22 µs [3.05–3.32] | 3.35 µs [3.00–3.49] |
| Fiber pair, no yields | Current-thread | 11.6 µs [11.1–12.6] | 11.9 µs [11.3–12.4] |
| Fiber pair, one yield each | Current-thread | 16.5 µs [16.1–16.8] | 16.6 µs [15.6–17.4] |
| Foreign completion round trip | Current-thread | 8.64 µs [7.95–8.96] | 8.25 µs [8.04–9.08] |
| IO loop step | Current-thread | 46.9 ns [41.3–48.8] | 45.7 ns [44.6–47.2] |
| Trivial `run()` | Pool | 4.21 µs [4.07–4.30] | 4.35 µs [4.07–4.92] |
| Fiber pair, no yields | Pool | 30.7 µs [30.1–31.5] | 30.9 µs [30.3–31.3] |
| Fiber pair, one yield each | Pool | 43.9 µs [43.1–45.4] | 44.5 µs [43.5–46.2] |
| Foreign completion round trip | Pool | 8.27 µs [8.05–8.90] | 8.55 µs [8.04–8.94] |
| IO loop step | Pool | 47.9 ns [45.8–50.1] | 45.9 ns [45.1–48.1] |
| Idle `run` for 2 s, process CPU | Pool | 0.71–1.26 ms | 0.53–1.27 ms |

- Every case is within run-to-run noise.
- **Trivial `run()` on the pool.** It first cost 4.71 µs, because the pool
  opened every worker's heap when it was created. Each heap now opens on
  its worker's first deadline (`_WorkerTimers`), and roots share one empty
  root heap.
- **Idle CPU.** Both trees are bimodal on this host, about 0.5–0.9 ms or
  1.1–1.3 ms per run, with medians near 0.9 ms. Neither parks differently: a
  worker with one pending sleep parks once, until its deadline.
- **Lateness under load.** `wstp_worker_timers` measures a median and 90th
  percentile of about 0.2 ms on an idle host. With four busy-looping
  processes on the four cores, `run_parks`' median-lateness check (1 ms)
  fails before and after alike, at about 2 ms: the host's scheduling
  latency.

### Blocking hand-off

On a work-stealing worker, `IO.blocking` and `IO.interruptible` hand the
worker to a replacement thread and run the call on the thread that made it,
following Cats Effect's `WorkerThread.prepareForBlocking`. The pool handles this
via `_WorkerRef.hand_off_for_blocking` in `src/fp/effects/_async/pool.mojo`.

**Routing.** A call's registration builds its job as on the blocking pool,
counted in the root's in-flight calls, then asks the worker running on this
thread (`_worker_on`) to take it. The worker refuses when it is not inside a
task run, already holds a call, the pool is closing, or the cap of calls
blocked at once is reached; a refused call queues on the root's
`BlockingPool`. A root with a configured `IORuntimeConfig.blocking_pool`
never hands off: the user's choice of pool, such as `max_workers=1` to run
calls one at a time, is honored on both profiles. The current-thread profile
is unchanged.

**After the run, not inside it.** The worker stashes the job in its slot's
owner-only `blocked` field and sets `retired`; the call's fiber suspends on its
registration as on the blocking pool. When the run ends the loop leaves and the
thread runs the call. So:

- the hand-off happens at a quiescent point, when nothing of the slot is in use
  (`running`, `settle` and ring pushes are finished);
- `interruptible`'s fiber is suspended, so its withdrawal can run on another
  worker while the call blocks, and cancel the call's token;
- `blocking` and `interruptible` share the blocking pool's `Completion` path and
  job, and differ from it only in the thread that runs the job.

**The protocol** (`_Pool._hand_off`):

1. The worker's last run ended. It is still counted active and not searching
   in `_Parking`, a state the replacement inherits. The replacement then asks
   to search (`transition_to_searching`) before its loop, as a worker that
   found nothing does: a non-searcher parks without re-checking the queues,
   which is safe only after a refusal, since a searcher re-checks after it.
   Keeping the inherited state lost the wake of a call completed from the
   thread that left, about once in 100 runs of `wstp_blocking`.
2. The thread leaves (`key` 0) first, so its later wakes, including the call's
   completion, go to the external queue: the ring keeps its one producer.
3. It takes the job and clears `retired`, its last writes to the slot.
4. It submits "run slot `i`" (`_SlotJob`) to the pool's thread cache, which
   claims an idle thread or starts one.
5. It runs the call with a poller of its own. It is no longer a worker:
   `_on_own_thread` does not count it, so `Runtime.run` there is allowed, as
   Cats Effect allows `unsafeRunSync` inside `blocking`, since it blocks no
   worker. After the call it touches no pool memory (the cap's count travels
   with the job), because the call's counts dropping can let its root, and so
   the runtime, finish.

The slot is the worker: the replacement runs `run_worker` on the same index
and inherits its ring, poller and the descriptors registered there, timer
heap, LIFO slot, `tick` and random state. Nothing is copied. Thieves keep
stealing from the ring while the replacement starts. Ownership of the slot's
owner-only fields passes in step 4: `pthread_create` orders a new thread
after it, and the cache queue's stripe lock (push, then pop) orders a cached
one.

**The thread cache** (`_Blockers`) is a private `_PoolCore`, the blocking
pool's core, with "run slot `i`" jobs, and the cap's count. A pool
makes it on its first hand-off and installs it with one compare-exchange
(ACQUIRE_RELEASE; a loser drops its threadless candidate), so a per-call
`run` that never blocks pays nothing for it: an eager cache cost the pool's
trivial `run()` about 0.8 µs. In the cache, idle threads park in their own pollers, a submitter claims
one or starts one, and an idle thread retires after the idle timeout (60 s,
`_DEFAULT_IDLE_SECONDS`). After its call a thread offers itself for reuse:

- a cache thread returns to the cache's idle loop;
- a started worker thread (`_start`) joins it through `_serve_adopted`, its
  join staying with `slot.thread`;
- the caller as worker 0 of a per-call run waits for its root instead.

Live cache threads stay below `workers + max_blocking_threads`, the cache's
maximum: a thread starts only when none is idle, so each live one runs a slot
(at most `workers`) or a call (at most the cap). If a thread cannot be
created while another is live, the slot's job waits in the cache queue. A
started worker that handed it off serves the queue after its call, its own
job included. The caller as worker 0 waits for its root instead, so after its
call it takes its slot back if no cache thread took the job yet
(`_SlotClaim`, one compare-exchange in its own allocation). Without
that step, worker 0's slot, with its timers and descriptors, waited until
some cache thread finished a call. A cache thread that pops a job already
claimed returns without touching the pool, which may be gone by then.

**The cap.** At most `max_blocking_threads` calls (64,
`_DEFAULT_MAX_WORKERS`) are handed off at once; further calls queue on the
root's pool, so the thread count stays bounded. Both values are `_Pool`
keyword parameters defaulting to `blocking_pool.mojo`'s constants, their one
owner; `IORuntimeConfig.max_blocking_threads` and
`blocking_idle_timeout` supply them.

**Shutdown.** `close_blocking()` closes the cache: it wakes the idle threads
and joins the threads the cache started, detaching the calling thread if it is
one. `shutdown` and `shutdown_on_worker` call it after interrupting the
workers and before joining `slot.thread`, so an idle adopted
thread does not hold the join for the idle timeout. Every handed-off call has
returned by then, since a root's finish waits for its in-flight calls. A
per-call `run` therefore leaves no thread behind.

**Orderings.**

| Word | Ordering |
|---|---|
| `_Blockers`' address | Installed once by compare-exchange from 0 (ACQUIRE_RELEASE), loaded ACQUIRE. |
| A slot job's claim (`_SlotClaim`) | One compare-exchange from 0, ACQUIRE_RELEASE on success, between the cache thread that pops the job and the caller as worker 0 after its call. Each side's view of the slot is already ordered (the stripe lock, `pthread_create`, or program order). |
| The cap's count (`_Calls`, its own allocation) | RELAXED. `begin_below` reads first and refuses a full count without writing, then increments and undoes an increment that went over. It bounds threads and orders no data. Each handed-off job holds a copy and releases it in `_Job.execute`, so a thread touches no pool memory after its call. |
| `blocked`, `retired` | Owner-only, set inside the run and read after it on the same thread. |
| The slot's hand-over | `pthread_create`, or the cache queue's stripe lock. |
| The root's in-flight calls | As on the blocking pool: RELAXED increment, RELEASE decrement, ACQUIRE wait. |
| The call's result | `Completion`. |

**Interactions.** The per-worker timers and descriptor registrations move
with the slot. A thread that left never arms into the slot's heap, since it
runs only the call. The LIFO slot's task is flushed to the ring
(`_flush_lifo`) before step 2, so thieves can take it during the start-up
gap; the loop-tail flush skips a retired worker. When a `Runtime`'s last copy
drops on a replacement thread (`shutdown_on_worker`), the slot's `keep` is
released by that thread (`_run_slot`), as by a started worker's
(`_worker_entry`).

The `wstp_blocking` client checks the hand-off on worker 0 with another fiber
progressing during a 100 ms call, cancellation waking `Interruption.sleep`
through the bridge, the cap overflowing onto the root's pool, an idle thread
reused and then retired, results and errors, and a configured
`BlockingPool(max_workers=1)` still running calls one at a time.

### Selecting the profile

`IORuntimeConfig.profile` selects the profile at run time: the free `run`
branches on it once (`_run_profile`), and `Runtime` reads it when created.
With the work-stealing profile, the free `run` uses a pool made for the call
(`_run_pooled`). `Driver`, `TestControl` and `run_pair` ignore it and always
use the current-thread profile.

By default, the runtime selects the work-stealing profile with one worker
per logical processor (or the current-thread profile on single-core hosts): a one-worker pool would pay the per-call pool,
the ceding pair and idle CPU with nothing to run in parallel. The default is
a sentinel (`_AUTO`) that `Profile._concrete` resolves when the profile is
read, through one hook, `_resolved(cores)`, which `public_runtime` calls with
forced counts; `_run_profile` and `Runtime` resolve it once per call. So a
default `IORuntimeConfig()` folds at compile time, and `num_logical_cores()`
runs only at run time. Building with `-D FP_ASYNC_PROFILE=current_thread`
makes it the current-thread profile, the default of earlier previews,
`-D FP_ASYNC_PROFILE=work_stealing` a pool with a worker per logical
processor even on one, and `-D FP_ASYNC_WORKERS=n` sets the pool's size. These overrides exist for
qualification, so that every client runs on both profiles unchanged: its own
routes select `current_thread` and its pool routes `work_stealing`. A profile
set explicitly in the configuration always wins, and clients that check
per-profile behavior ask the resolved default
(`_default_profile().is_work_stealing()`) at run time. `Profile` sits in its own leaf module because `IORuntimeConfig`
holds one, and `runtime.mojo` imports the pool, which imports the kernel.

`qualify.py` builds every client in `POOL_CLIENTS`, which includes
`foreign_completion` and `foreign_signal`, twice more, from source
and from the package, through `CompileCase.defines`. Where a client checked an
order that only the current-thread profile promises, it keeps that check on
the current-thread route and checks the invariant on the pool route:

- `fiber_race_pair`: a tie selects either side, and the first completion
  observed wins; the canceled loser's join sees its own
  success or the cancellation;
- `fiber_basics`: the interleaving of a fiber with its owner;
- `fiber_reporting`: the "(canceled)" mark of a failure that settles while
  its owner drains.

`fiber_drain` now signals entry from inside its guarded region, which makes
its precondition hold on both profiles.

### The runtime

`Runtime` (`runtime.mojo`) is the public owner of a pool, after Cats Effect's
`IORuntime`. Its copies hold one `ArcPointer` to a
`_RuntimeCore`, whose destructor is the shutdown.

- **Creation.** With the work-stealing profile, `_Pool(workers, 0)` and
  `start_all`, which raises `OSError` when a thread cannot start; the
  workers already started are then shut down. The current-thread profile
  starts nothing.
- **`run`.** On the pool: `_submit_root` with the root's fiber table shared,
  registration in the core's list of live roots, `_RootHandle.wait` (the
  caller spins, then parks in its own poller; see
  [the caller's wait](#the-callers-wait)), removal, then `take`. On the current
  thread: a driver whose table is shared, registered, then driven by the
  free `run`'s loop (`kernel._drive`). `run` on one of the runtime's own
  workers aborts; `_on_own_thread(pool)` is the one test of that. The
  blocking hand-off's replacement threads hold the worker key and count; a
  thread inside a handed-off call is no longer a worker and touches no pool
  memory after its call (see [Blocking hand-off](#blocking-hand-off)).
- **`fibers()`** copies the live roots under the lock and snapshots each
  root's table outside it, numbering the root in `FiberInfo.root`. A table
  created shared (`share_snapshots`) may be read from any thread: a reader
  count with a Dekker handshake keeps a finishing fiber from freeing its task
  state while a snapshot reads it (`fiber_slots.mojo`). Only the roots of a
  `Runtime` pay for it; the free `run` and `Driver` keep the RELEASE clear.
- **Shutdown**, when the last copy is dropped:
  1. Cancel and drain: request cancellation of every registered root and
     wait until none remains. This finds nothing: every caller of `run`
     borrows a copy for the whole call, and every `eval_on` region, the one
     kind of root nobody waits for, holds a copy until it has finished and
     unregisters before dropping it
     ([execution contexts](#execution-contexts)). So the last copy
     goes only after every registered root completed, and a root completes
     only after its fibers. The step keeps the contract for a later public
     `unsafeRunAndForget`-style call.
  2. `shutdown`: publish `closing`, claim the workers never started,
     interrupt the rest and join them. Each leaving worker drops what is left
     on its ring on its own thread (`drain_on_shutdown`, which first flushes
     its LIFO slot into the ring), and `shutdown` then empties the external
     queue, so no task is destroyed inside the pool's destructor. Such
     entries can only be stale wakes of finished tasks.
  3. On one of the runtime's own workers, as when a finished root's program
     state held the last copy and is destroyed there, the thread cannot join
     itself. `shutdown_on_worker` joins the others, detaches this worker's
     thread and moves the pool's last reference into the slot's `keep`; the
     worker finishes its run, leaves its loop, and its thread drops the pool
     last (`_worker_entry`), as a `BlockingPool` worker does.

`wstp_shutdown` checks the joins over repeated runtimes, copies, and the
detach path, which it reaches deterministically by submitting a root through
`_submit_root` without a caller's copy. `public_runtime` covers shared
copies, many programs from two threads, numbered dumps, both profiles, a
per-call `run` that starts no thread, and snapshots racing fiber completion;
`runtime_own_worker` is the death test for `run` on an own worker.

### The caller's wait

The thread calling `Runtime.run` is not a worker, so it waits for its root
on its own. Earlier it always parked in a fresh poller, and paid the
poller's creation and the operating system's wake latency, about 0.1 ms on
this virtual machine: `Runtime.run(IO.pure(x))` took about 52 µs on an idle
host, against about 4 µs for the free `run`, whose caller is worker 0.

`_RootHandle.wait` now first waits without parking (`_spin_for_done`): it
reads the root's state `_UNPARK_SPINS` (64) times, then yields between reads
until 50 µs pass, as the pool's unpark paths wait for a short step, and parks
only if the root is still running. A busy loop would cost a long program 50 µs
of CPU on every run, so the pool counts the waits that ended parked in a row
(`parked_waits`, RELAXED, a heuristic), and while that count is nonzero only
every 16th wait spins; one that completes in the window resets it. Long
programs therefore spin once in 16 runs, and a program that turns short is
noticed within 16 runs.

Measured with `probes/runtime_run_cost.mojo` at O3 on the 4-core host, a
4-worker runtime, medians of 6 round medians, built back to back with the
previous build, `62cb25f`:

| Case | Before | With the wait |
|---|---|---|
| `run(IO.pure(x))`, idle host | 60–75 µs | 32–37 µs |
| Start and join one child, idle host | 69–96 µs | 59–81 µs |
| Ten cedes, idle host | 102–110 µs | 95–114 µs |
| Free `run(IO.pure(x))`, for reference | 3.8–4.9 µs | 3.8–5.1 µs |
| CPU per run of a 5 ms sleep | 331 µs | 335 µs |
| CPU of an idle 2 s run | 439 µs | 437 µs |
| `run(IO.pure(x))`, four busy processes on four cores | 3.7–4.3 ms | 2.5–3.9 ms |

The rest of an idle run is mostly the submitting side: the root goes to the
external queue and a parked worker is woken through its poller, at the same
wake latency. Removing it would need workers to spin before they park, a
pool-wide cost in idle CPU for every program, which this change does not
make. Under load the workers wait for the operating system to schedule them,
and the wait cannot help.

### Execution contexts

`io.eval_on(target)` runs `io` as its own root on
the target and resumes the caller on its own root, the separate-root approach:
a fiber never migrates between schedulers. `contexts.mojo` is the caller's
side, an `IO.async` registration that shares `interruptible`'s machinery:

1. A leaf reads the caller's interpreter settings from its `_Budget`, for a
   `BlockingPool` target, which has no configuration of its own.
2. The registration (`_SubmitRegion`) starts the region's root under a fresh
   token held in an `_Interrupt`, the type `interruptible` uses, and is
   unmasked, so canceling the caller reaches `io`'s checkpoints.
3. When the root has finished and released everything, `_RegionDone`
   completes the registration's `Completion` and reports the return.
4. The withdrawal is `_AwaitReturn`: it cancels the region's token and waits
   for that report, so the caller never resumes while the region still runs,
   and `io`'s finalizers run on the target exactly once.

How a region's root runs on each kind of target:

| Target | Where the region runs | `execution_context` inside | Cancellation | Cost |
|---|---|---|---|---|
| Work-stealing `Runtime` | A detached root on the runtime's workers (`Runtime._start_region`) | The runtime | The region's token, seen at its checkpoints; workers poll it like any root's | One root submission and a foreign wake, about a `runtime.run` |
| Current-thread `Runtime` | A current-thread root driven by `kernel._drive` on one thread of the runtime's region pool: `config.blocking_pool`, or a private `BlockingPool` made with the runtime, which starts no thread until a region | The runtime | The token wakes the parked driver through the root's token subscription | A job on the pool, a driver, and a foreign wake; the thread is held for the region's whole length |
| `BlockingPool` | The same, on one of the pool's threads, with the caller's interpreter settings and no configured blocking pool | The pool | As above; a region queued behind a busy pool starts already canceled and ends at its first step | As above |

**The detached root.** `_queue_root` takes a `_RootSink`, the place a pool
root's outcome goes on the worker that finishes it. `_Waited` publishes it
for a thread waiting on a `_RootHandle`, as before. A region's sink,
`_DetachedRoot`, takes the handle itself, in this order:

1. `_release_root`: wait for the root's blocking calls, shut its scheduler
   down, which also frees its context, and close its poller. `_RootHandle.take`
   shares the function. Either may run while the worker still settles the
   root's task, which touches only the task's registry.
2. Unregister the root from the runtime.
3. Drop the region's copy of the runtime. When it is the last, the runtime
   shuts down from this worker (`shutdown_on_worker`), which cannot deadlock:
   every registered root holds a copy, so cancel-and-drain finds none.
4. Deliver the outcome (`_RegionDone`), which resumes the caller.

Registration, and the context below, happen before the root is queued, for
`Runtime.run` too, so a root that completes at once is never left
registered. A current-thread region runs `_drive_here`, which
`Runtime.run`'s current-thread branch shares, then drops the target's copies
before delivering the outcome; a pool's last copy then closes the pool from
its own worker, as `BlockingPool` allows.

**The context word.** `_SchedulerWords.context` is 0 or the address of an
owned `_Erased` box holding the root's `ExecutionContext`. `Runtime.run` and
regions store it RELEASE once, before the root is queued or driven; the
root's fibers load it ACQUIRE (`IO.execution_context`); `_Scheduler.shutdown`
takes it back to 0 and frees it after the root completed, when no reader
remains, so a scheduler kept alive by a stale waker holds no runtime copy.
`IOContext` is unchanged.

**Rejections.** `Fiber`, `Supervisor` and `Poll` conform to the private
marker `_RootBound`. `eval_on` asserts at compile time that its value and
error types reach none, through struct fields, `List` and `Optional`
(`_root_bound_offender` in `thread_safety.mojo`). A `where` clause cannot
evaluate that walk, so `EvalOnCompatible` checks only the carrier and
`IO.eval_on`, which every path reaches, asserts the rest.

`eval_on_basics`, `eval_on_cancel`, `eval_on_lifetime` and `eval_on_laws`
cover every target, on both profiles of the caller.

### Interim limits

- **Fiber snapshots.** `Driver.fibers()` stays on the current-thread
  profile; `Runtime.fibers()` covers both (see [the runtime](#the-runtime)).

### Memory ordering

| Word | Ordering |
|---|---|
| Task state, inline in its header | Unchanged from the current-thread profile. It is reached only through the task's `ArcPointer` (`_TaskHeader.state_of`), never through a borrowed header, so one allocation per task suffices. |
| Ring entries | The ring's RELEASE tail store and ACQUIRE loads, or a steal's ACQUIRE claim, order a task's body between workers (`local_queue.mojo`). |
| Slot `poller` | Stored SEQUENTIAL once, before the worker first publishes PARKED. A notifier loads it ACQUIRE after claiming the flag. Shutdown stores `closing` and then loads this word, SEQUENTIAL, against the worker's store and its later load of `closing`. |
| Slot `thread` | Written by the starter before `finish_unpark` (RELEASE). Shutdown reads it after `wait_unparked`'s ACQUIRE loads. |
| `closing` | SEQUENTIAL store and loads. |
| The root scheduler's `in_flight` and `closed` | The notify-or-close handshake of [the scheduler's words](#the-schedulers-words), unchanged, now also around a foreign wake on a pool. `push` increments SEQUENTIAL, then loads `closed` SEQUENTIAL: closed drops the push. `notify_host` decrements with RELEASE after the pool's notify. `close` stores `closed` SEQUENTIAL and waits for the count. Either the wake sees the root closed, or the close waits for the wake, so no foreign wake touches a pool after its root closed. |
| `failed_starts`, `stolen_timers`, `delivered_wakes` | RELAXED; diagnostic counts, read only by tests and probes. |
| Worker timer heaps | `scheduling/timer_heap.mojo`'s orderings, unchanged. A heap ticket reaches a canceling thread only through its registry node, under the registry's lock. |
| Poller registration words | See [timers and descriptors per worker](#timers-and-descriptors-per-worker). |
| `_SchedulerWords.context` | Stored RELEASE once before the root runs; loaded ACQUIRE by the root's fibers; taken and freed by `shutdown` after the root completed ([execution contexts](#execution-contexts)). |
| `parked_waits` | RELAXED; a heuristic count of `Runtime.run` waits that parked in a row, which orders no data (`_spin_for_done`). |
| `_RootDone` | The completer stores completing and loads the waiter, SEQUENTIAL, then stores complete with RELEASE. The waiter stores its address and loads the state, SEQUENTIAL, and leaves only on an ACQUIRE load of complete. |
| Fiber-slot shard heads | As before, one tagged free stack per worker. A start whose shard is empty scans the others before growing the table, which keeps it bounded. |
| `_RuntimeCore`'s live roots | Behind the shared spin lock (`_Cell`), held only to add, remove or copy entries; `fibers()` snapshots each root outside it. |
| A shared fiber table's `readers` and cleared entries | A Dekker handshake: a snapshot increments `readers` and loads entries SEQUENTIAL, dereferences task states ACQUIRE, and decrements RELEASE; a release clears its entry SEQUENTIAL, loads `readers` SEQUENTIAL and spins on ACQUIRE loads while it is nonzero (`fiber_slots.mojo`). Unshared tables keep the RELEASE clear. |
| Slot `keep` | Owner-only: written by `shutdown_on_worker` on the worker's own thread, taken by the same thread after its loop. |
| One-shot cell in a fiber record | As before. The cell now sits inside the record's allocation, reached through the view's address. |

### Measurements

O3, on this 4-core host. Current-thread figures are against the previous
build, without the pool, built back to back; each is the median of six
rounds, with the range in brackets.

| Case | Previous build | Current-thread | Pool |
|---|---|---|---|
| Trivial `run()` | 3.35 µs [3.18–3.69] | 3.16 µs [3.12–3.34] | 4.21 µs [4.13–4.60] |
| Fiber pair, no yields | 11.4 µs | 11.2 µs | 32.8 µs |
| Fiber pair, one yield each | 16.4 µs | 15.8 µs | 50.6 µs |
| Foreign completion round trip | 8.96 µs | 8.98 µs | 8.98 µs |
| Join racing a completion | 6.82 µs [6.68–7.22] | 7.01 µs [6.62–7.30] | 22.5 µs |
| IO loop step | 47 ns | 45 ns | 45 ns |
| Idle `run` for 2 s, process CPU | — | 0.23–0.28 ms | 0.74–0.87 ms |

- **The current-thread profile shows no regression.**
- **Parallel speedup.** `wstp_parallel` (16 CPU-bound fibers of 40 steps)
  takes 55 ms on one worker, 27 ms on two (1.98×) and 15 ms on four (3.49×).
- **The cost of tiny fibers.** A fiber pair and a join cost about three
  times as much on the pool. The pushing worker wakes another worker, which
  steals the child and completes it across threads, at the poller's wake
  latency. The LIFO slot (above) removes that cost.

### Held coordination locks

Contention on held coordination locks was measured under the work-stealing
pool via `probes/wstp_coordination_cost.mojo`: 16 fibers update one `Ref` 200
times each, with a callback that spins under the lock. Today an attempt that finds
the lock held is rescheduled at once, so waiting workers busy-poll. Four workers
burn 3.9 cores for 1 core of serialized work:

| Callback | 1 worker | 4 workers, polling (kept) | 4 workers, spin then wait on the owner's signal |
|---|---|---|---|
| Empty | 1.06 µs | 0.85 µs, 355% CPU | 1.40 µs, 370% CPU |
| 2,000 rounds | 5.3 µs | 5.0 µs, 387% CPU | 6.2–6.7 µs, 380% CPU |
| 20,000 rounds | 44 µs | 44 µs, 393% CPU | 59–61 µs, 212% CPU |

The waiting variant was built and measured, then left out. A contended word
marked by a failed attempt made the release notify the owner's signal, after
128 spins. Waiting saved CPU only for callbacks that hold the lock for tens of
microseconds, and lost throughput everywhere. Every release wakes all the
waiters, and the next holder usually sits on a parked worker, a pipe wake
away. Callbacks under the lock must stay short, as the contract says.

#### Evaluation of wake-one wait queues

A prototype wake-one wait queue was evaluated for `Ref.update`'s attempt (`_Once`).
Polling was retained: while the queue reduced CPU usage, immediate rescheduling
delivered consistently higher throughput across callback lengths.

**Design.** Only one waiter polls; the rest sleep, and each acquisition
wakes exactly one.

- **The queue.** A contended cell gets a FIFO of waiters, made on its first
  contention and installed in the cell by one compare-exchange. An attempt
  that finds the lock held joins it once, with a node that holds a private
  `Signal`.
- **The head polls.** The node at the front reschedules itself, as every
  attempt does today, so a release is taken at once and never needs to wake
  anyone. The others wait on their own signal.
- **Hand-over.** When the head acquires the lock it leaves the queue and
  notifies the new head's signal: one wake per acquisition, never a herd. A
  woken node polls in turn.
- **Leaving.** A waiter that is canceled, or whose machine is dropped, leaves
  the queue; a departing head notifies the next.
- **Unchanged.** The lock word, the release path (`_Guard`), the synchronous
  family, `Permit`'s destructor and the uncontended path, which pays nothing.
  A running fiber can still take a free lock ahead of the queue, as today.

**Why no wake is lost.** While the queue is not empty its head is awake and
polling, so a release needs no notification. A sleeping waiter reads its
signal's revision, then checks under the queue's lock whether it became the
head. A promoter pops the old head under the same lock, then notifies. Either
the waiter saw itself at the front and polls, or the notify follows its read
and `Wait.changed` sees the new revision.

| Word | Ordering |
|---|---|
| The cell's queue address | Installed by compare-exchange from 0, ACQUIRE_RELEASE on success; loaded ACQUIRE (a losing installer frees its candidate) |
| The queue's nodes | Under its `_lock_cell` lock: ACQUIRE claim, RELEASE release |
| A node's signal | `Signal`'s own lock orders the notify against the waiter's revision read and subscription |
| The coordination lock | Unchanged: `_try_lock`'s sequentially consistent compare-exchange and release store |

**Cost.** Uncontended, nothing. Contended, one node and one `Signal` per
waiting operation, and the queue's lock on every join, check and leave.

**Measurements**, the probe at O3 on this host, built back to back: polling,
as kept, against the queue, two rounds each.

| Callback | 1 worker | 4 workers, polling (kept) | 4 workers, wake-one queue |
|---|---|---|---|
| Empty | 1.04 µs | 0.78–0.86 µs, 356–364% CPU | 1.09–1.17 µs, 115–125% CPU |
| 2,000 rounds | 5.3–6.3 µs | 4.95–5.01 µs, 387% CPU | 5.45–5.46 µs, 102% CPU |
| 20,000 rounds | 43.8–43.9 µs | 43.2–43.9 µs, 393–394% CPU | 44.1–46.3 µs, 100% CPU |

The queue keeps one worker busy instead of four, but loses about 30% of
throughput with empty callbacks and 9% at 2,000 rounds, and is at best even
at 20,000. Polling gains from the other workers running the non-critical part
of each update (its continuations and allocation) in parallel, while a
sleeping waiter does none of it, so this loss is inherent to sleeping rather
than to the queue's cost. The queue would be adopted only if throughput held
at every length, so it is not adopted, and the prototype is not
merged. A program whose callbacks hold a lock for a long time pays the
polling CPU; the contract already asks for short callbacks.

### Profiles compared

Both profiles were measured across the gate cases and the existing probes'
operations with `probes/profile_compare.mojo`, which runs each case through
the public `run` with an explicit profile, so one binary measures both and
the same file builds against the previous build. That serves the performance
gates: no regression against the previous build in a trivial `run()`, a
fiber pair, a join, a foreign round trip and the IO loop step. O3 on this
4-core host, the pool with four workers; each figure is the median of six
rounds, and each cell gives two runs of the probe taken back to back,
alternating between the previous build (before) and this one (after).

| Case | Current-thread, before | Current-thread, after | Pool, before | Pool, after |
|---|---|---|---|---|
| Trivial `run()` | 3.23, 3.28 µs | 3.41, 3.28 µs | 4.27, 4.24 µs | 4.28, 4.24 µs |
| Fiber pair, no yields | 10.9, 12.4 µs | 11.2, 10.5 µs | 10.6, 11.4 µs | 10.8, 10.4 µs |
| Fiber pair, one cede each | 17.1, 15.9 µs | 16.3, 18.1 µs | 36.7, 40.0 µs | 36.3, 37.0 µs |
| Join racing a completion | 6.55, 6.56 µs | 6.87, 6.66 µs | 6.41, 7.13 µs | 6.79, 6.58 µs |
| Foreign completion round trip | 8.93, 9.75 µs | 9.22, 8.98 µs | 9.73, 10.1 µs | 9.93, 9.22 µs |
| 1,000 starts under one scope, per fiber | 5.04, 8.39 µs | 5.08, 5.26 µs | 4.36, 4.90 µs | 4.49, 5.07 µs |
| IO loop step | 17–34 ns | 19–32 ns | 17–34 ns | 18–33 ns |
| `both` of two pure sides | 10.6, 11.2 µs | 10.1, 10.8 µs | 12.0, 13.3 µs | 12.7, 13.1 µs |
| `race` of two pure sides | 9.97, 10.0 µs | 10.0, 10.9 µs | 11.8, 11.6 µs | 11.5, 12.9 µs |
| `par_traverse` of 1,000 cedes, per element (six runs) | 7.82–8.77 µs | 8.00–9.31 µs | 4.72–6.56 µs | 4.52–6.62 µs |
| 1 ms sleep lateness, median and 90th percentile | 99 and 135, 131 and 158 µs | 106 and 139, 135 and 193 µs | 137 and 176, 136 and 172 µs | 126 and 173, 151 and 199 µs |
| Idle `run` of 2 s, process CPU | 198, 204 µs | 194, 188 µs | 452, 510 µs | 482, 480 µs |

Throughput with many workers, from the clients and probes that measure it:

| Case | Current-thread (one worker) | Pool, two workers | Pool, four workers |
|---|---|---|---|
| `wstp_parallel`: 16 CPU-bound fibers, six runs | 54–56 ms | 27–29 ms (1.82–1.97×) | 14–15 ms (3.52–3.97×) |
| One `Ref` under 16 fibers, empty callback ([above](#held-coordination-locks)) | 1.04 µs per update | — | 0.78–0.86 µs, 356–364% CPU |
| The same, 20,000-round callback | 43.8 µs | — | 43.2–43.9 µs, 394% CPU |

- **Gates.** Every case of this build overlaps the previous build's runs on
  both profiles.
  The IO loop step is bimodal on this host on both trees, either about 17 ns
  or about 33 ns per run, so it is given as the range of six runs.
- **Where the pool costs more.** A trivial `run()` makes a pool for the call
  (about 1 µs). A fiber that cedes requeues onto the ring, where a second
  entry wakes another worker, so a ceding pair costs about twice the
  current-thread profile ([see notification policy](#ceding-pairs-and-notification-policy)). `both` and `race` start their sides as fibers and
  cost 15–25% more. An idle pool parks its worker in a poller like the
  current thread, but a 2 s run uses about 0.3 ms more CPU.
- **Where it wins.** Fiber pairs and joins match the current-thread profile
  (the LIFO slot), and fan-outs run in parallel: `par_traverse`'s
  per-element cost falls by a quarter even for elements that only cede, and
  CPU-bound fibers speed up nearly linearly.
- **Latency.** Timers fire 0.1–0.2 ms after their deadlines on both profiles,
  and a foreign completion's round trip is the same.

### Ceding pairs and notification policy

A fiber that cedes, or that a wake marked notified during its run, is
requeued at the end of its run (`_Runtime.park`) behind whatever its
worker's ring holds. A second entry wakes a parked worker under the ring's
rule. That worker steals at the poller's wake latency, so two fibers ceding
to each other cost about twice as much on the pool as on the current thread.
The runtime notifies immediately on every such requeue, aligning with Cats
Effect's `cede` and Tokio's `yield_now` to ensure fair scheduling and low
wake latency across worker threads.

**The mechanism tried.** A requeue after a run of at least a delay T
notified at once, as today. A requeue after a shorter run that would have
notified deferred instead. After each later run, the worker cleared the
deferral if its ring was empty, and notified once the deferral had lasted T.
A worker leaving its loop notified at once. No wake could be lost, because
the deferred task sat on the ring of a running worker, which drains its ring
before it parks.

**The measurements.** O3 on the 4-core host, back to back against the
baseline without the deferral (6688e01), medians of six rounds, with
`probes/profile_compare.mojo` and `probes/cede_fanout.mojo`, T swept over 10,
20 and 50 µs:

| Case | Baseline | 10 µs | 20 µs | 50 µs |
|---|---|---|---|---|
| Fiber pair, one cede each, pool (current thread 18.0–18.6 µs) | 36.1 µs | 20.7 µs | 20.8 µs | 19.2 µs |
| `wstp_parallel`, six runs, 2 and 4 workers | 1.85–2.00×, 3.50–3.77× | 1.89–1.97×, 3.57–3.78× | 1.93–2.12×, 3.59–3.93× | 1.93–2.04×, 3.67–3.90× |
| 2 and 4 fibers ceding every ~4 µs, on 2 and 4 workers | 1.68×, 3.72× | 1.78×, 3.32× | 2.01×, 3.29× | 1.69×, 3.45× |
| The same, every ~22 µs | 1.95×, 3.98× | 1.87×, 3.79× | 1.90×, 3.83× | 1.88×, 4.01× |
| The same, every ~107 µs | 1.88×, 3.90× | 1.87×, 3.55× | 1.95×, 3.87× | 1.93×, 3.89× |
| A fiber ceding 20 times beside a 1 ms step, 2 and 4 workers | 128 µs, 164 µs | 1048 µs, 1032 µs | 988 µs, 991 µs | 977 µs, 1009 µs |
| The same beside a 5 ms step | 199 µs, 197 µs | 5.00 ms, 4.96 ms | 4.55 ms, 4.57 ms | 4.68 ms, 4.76 ms |

The ceding pair came within about 2 µs of the current-thread profile. The
parallel speedups and the fan-outs held within this host's noise. The
performance gates' cases on the pool overlapped the baseline's ranges, with
no visible cost from the added clock read: trivial `run()`, fiber pair, join,
foreign round trip, starts, `both` and `race`. But a short fiber that cedes
beside a sibling whose single step never yields waited out that whole step,
about 1 ms and 5 ms, where today it reaches another worker in 0.13–0.2 ms.

**Why T cannot fix it.** When a fiber requeues, the sibling of a ceding pair
and a long sibling look the same: each is an entry on the ring that has not
run yet. Once the worker starts that entry, nothing on it can act until the
run ends, and only a notify reaches another thread, which is the very cost
the deferral removed. The added wait is the smaller of the transition slice
and one step that never yields, whatever T is.

**What stays.** A ceding pair costs about twice as much on the pool as on
the current-thread profile. For code dominated by ceding hand-offs, choose
`Profile.current_thread()`. Or hand off through `Deferred` or `Queue`: their
wakes come from the running task and take the LIFO slot's path, which needs
no notify. The probe stays in the repository as evidence.

### Qualification

`wstp_parallel`, `wstp_wakes` and `wstp_ownership` run on four-worker pools
through `_run_pooled`; they check invariants, never which worker ran what or
which side won.

- **`wstp_parallel`** checks results, the absence of overlap on one worker,
  overlap on two and four workers, and a speedup of at least 15%.
- **`wstp_wakes`** covers three cases:
  - a storm of `IO.async` completions from three OS threads;
  - a relay of a token through one-slot queues between fibers on different
    workers;
  - after an idle period in which every worker parks, new work for which
    the pool delivers a wake, and which then finishes with every step run
    once and every value right. The wake is counted by the pool's private
    `delivered_wakes` diagnostic: claims in `_Pool.notify` that interrupted
    a parked worker or started one. The part reports, and does not check,
    how many threads ran the work. The earlier check, "more than one thread
    ran the second burst", was soaked on a loaded host (three test processes
    on four cores), where it failed about one run in ten. Every failing run
    had delivered its wake: worker 0, leaving its timed park as a searcher,
    found the root, notified as the last searcher, and woke a parked worker.
    That worker was still counted searching when the burst was pushed, so
    the pushes rightly woke no one else, but it got no processor before
    worker 0 had run the whole burst alone (about 6 ms). The part sleeps
    again, 50 times at most, until a wake was delivered, so a worker slow to
    park cannot fail it. With a lost wake, where the parking counts claim a
    searcher that does not exist, no wake is delivered and the part fails;
  - 200 runs whose registrations a foreign thread completes before, during
    and after the root completes, with every payload destroyed exactly once.
- **`wstp_ownership`** covers:
  - owners draining children that cede forever;
  - joins across workers;
  - 200 races in which exactly one side wins and only losers are canceled;
  - unjoined plain and supervised failures, each reported exactly once
    through a reporter that writes to a pipe.
- **`wstp_wakes`' one-worker part** runs 40 roots on a one-worker pool,
  each awaiting 150 foreign completions that race the worker's park.
- **`wstp_stress`** draws random program trees from a seed it prints
  and runs each on a four-worker pool and on the current-thread profile:
  spawns and joins, cancellations, races, `both`, `par_traverse`, sleeps,
  blocking calls (hand-offs on the pool), `IO.async` registrations that two
  foreign threads complete, failures caught by `attempt`, and unjoined
  failing fibers. Every run checks the plan's value, each race winner's
  value, joined and canceled fibers' outcomes and `par_traverse`'s order,
  and exactly-once accounting: every tracked payload is destroyed once, and
  every raised failure is observed once, by its `attempt`, as the error of
  the race or canceled join above it, or by the reporter, and never by the
  root. Suppressing one report in five made it abort on both profiles. Its
  timing-dependent totals go to standard error.

### Concurrency audit and stress testing

Every shared structure is audited against strict memory ordering invariants (the
[ordering audit](async-thread-safety.md#memory-ordering-audit) lists them with
their clients), accompanied by rigorous stress and soak test runs on the work-stealing pool.
Key concurrency fixes verified include:

- **Started thread park synchronization** (`_Parking.prepare_to_park`).
  A newly started worker synchronizes unpark flags with its starter, ensuring
  parking counts and searcher states stay accurately tracked under high churn.
- **Single-worker pools park re-check** (`_find`).
  Sole workers on single-CPU hosts re-check the external queue before parking,
  ensuring late completions wake the thread reliably.
- **Worker slot reclamation during blocking offload**
  ([blocking hand-off](#blocking-hand-off), `_SlotClaim`).
- **External queue published length lock ordering:**
  Guards are kept alive past the published length store, preserving proper lock ordering
  ([ordering audit](async-thread-safety.md#memory-ordering-audit)).

One unclassified `wstp_lifo` abort, seen while the LIFO slot was developed,
did not recur in 500 runs with output captured. Its likely cause is the lost
first park, which leaves a parked worker that cannot be woken for a displaced
fiber.

**Soaks**, at O3 on four-worker pools after the fixes, 200 runs each with
output captured: every `wstp_*` client (`wstp_stress` with seeds 5001 to
5200, `wstp_lifo`, `wstp_wakes`, `wstp_ownership`, `wstp_blocking`,
`wstp_shutdown`, `wstp_queues`, `wstp_timers`, `wstp_parking`,
`wstp_worker_timers` and `wstp_parallel`) and the race clients
(`race_oneshot`, `race_stack`, `race_record`, `race_supervisor`,
`race_registrations`, `race_par_group` and `race_stack_take`) passed 3,600
of 3,600.

**Host notes.** Idle CPU on the pool is bimodal on this host, on the
previous build too: 0.39–0.62 ms per idle 2 s run in the
[profile comparison](#profiles-compared). The IO
loop step is bimodal too, about 17 or 33 ns on both trees. `run_parks`'
1 ms median-lateness check measures the host's scheduling latency and
fails under heavy load, on every tree; quiet, timers fire 0.1–0.2 ms late on
both profiles. A thread sanitizer does not run for Mojo executables in this
container, so the stress clients are the evidence that the documented memory
orderings hold.

## Polling system

The polling system is implemented in the private module `fp.effects._async.polling`,
following Cats Effect's `PollingSystem` (`poll`, `needsPoll`, `interrupt`) and Scala
Native's interruptible wait design. Its one implementation waits in POSIX `poll()` on the
registered descriptors and a self-pipe from `fp._internal.os`. Each root parks
in one (see [root parking](#root-parking-and-the-wake-hook)), each
blocking-pool worker parks in its own, and `SyncIO`'s interruptible waits park
in one per call.

- **Ownership.** `_Poller` belongs to one owner thread: one per root, and
  one per work-stealing worker, as each Cats Effect worker owns its poller.
  Only the owner calls `poll`, `register`, `deregister` and `readiness`.
  Other threads hold `_Interrupter` copies, which share the wake state but
  never borrow the poller, and can only `interrupt` or `close`, or release a
  registration they were handed (below). The caller owns its descriptors
  and keeps them open and nonblocking while registered; the poller owns only
  its pipe.
- **`poll(timeout)`** waits indefinitely, or up to a timeout, and reports how
  many registrations became ready, whether an interrupt arrived, whether the
  timeout expired, and whether the poller is closed. `poll()` counts whole
  milliseconds, so the poller polls for the whole milliseconds left, rounded
  down, against `std.time.monotonic()`, and waits the final part under 1 ms with
  `std.time.sleep` between two nonblocking polls. A wait therefore never ends
  early, and an interrupt or readiness during that last sleep is delayed by
  under 1 ms.
- **`interrupt()`** is safe from any thread. It sets a pending flag and writes
  one byte to the pipe only when the flag was clear, so repeated interrupts
  coalesce into one byte and one wake; a coalesced interrupt costs one fence and
  one load. A `poll` that returns drains the pipe if it was readable, then
  clears the flag, and the owner re-checks its work before polling again. An
  interrupter publishes its work, then executes a sequentially consistent fence
  and reads the flag. The owner clears it with a sequentially consistent
  compare-exchange followed by a fence. One of them sees the other: the
  interrupter sees the cleared flag and writes a byte the next poll finds, or
  the owner's re-check sees the work. Because the pipe is drained only before
  the flag clears, a late byte causes at most one spurious wake.
- **Registrations.** `register(fd, interest, signal)` watches a descriptor for
  read and/or write interest and returns a generation-checked handle. The first
  poll that sees the descriptor ready records its events, stops watching it,
  and notifies the `Signal`, so a waiter suspends with
  `Wait.changed(signal, revision)` like any other external event. Readiness is
  reported once, because `poll()` is level-triggered and a ready descriptor
  left armed would return every poll at once. `deregister` removes a
  registration when its waiter completes or is canceled, and a stale handle
  changes nothing, as with the wake registries. `needs_poll()` reports armed
  registrations: an owner without any can park more cheaply, which is the input
  the work-stealing pool's parking uses. `has_registrations()` also counts
  reported registrations not yet removed.
- **Closing.** `close()`, from any thread, wakes a poll in progress. A closed
  poller rejects new registrations, and the owner's next poll, or the poller's
  destruction, notifies every registration still armed, which then reports
  `closed()`. A word next to the flag counts the pipe's users: polls and
  interrupts in progress. Whoever leaves last after closing wins one
  compare-exchange and closes both ends, exactly once, so no write can reach a
  descriptor number the process has reused. Interrupters may outlive the
  poller; they do nothing once it is closed.
- **Releases from other threads.** Each registration's state lives in
  an atomic word, `generation << 3 | state`, apart from the owner's table.
  Another thread never touches the table: `_release_registration` marks the
  word released and counts it, interrupting the owner if the registration was
  still armed, and the owner's next poll removes released registrations. A
  work-stealing worker's descriptor waits use this when the fiber finishes on
  another worker; see [timers and descriptors per
  worker](#timers-and-descriptors-per-worker).

The `poller` client runs every cross-thread case on `OSThread`s:

- interrupts racing a park, with randomized delays on both sides, a time
  bound per round, and no lost wake in 3,000 rounds; clearing the flag before
  draining the pipe makes it fail on every run;
- 81,000 interrupts from five threads that leave one byte and one wake;
- read and write readiness on pipes, including a full pipe that becomes
  writable;
- removal on completion and on cancellation, and stale handles rejected after
  a slot is reused;
- closing during a poll, on the owner, on drop, and racing interrupts, with
  the pipe released afterwards;
- timeouts from 0 to 10 ms, including sub-millisecond deadlines;
- a 500 ms idle poll that uses almost no thread CPU time
  (`getrusage(RUSAGE_THREAD)`).

Measurements from `probes/poller_cost.mojo` at O3 on the same 4-core host:

| Operation | ns |
|---|---|
| Coalesced `interrupt()` (flag already set) | 6–7 |
| `poll(0)`, nothing registered | 470–510 |
| `poll(0)`, 16 armed descriptors | 960–1,120 |
| `interrupt()` then the `poll(0)` that drains it | 2,050–2,070 |
| Cross-thread wake round trip between two parked threads | 45,000–47,500 |

The round trip includes two operating-system wakes of parked threads on this
virtualized host.
