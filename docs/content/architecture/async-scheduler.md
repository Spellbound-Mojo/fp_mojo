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

The public `run` and internal `run_pair` delegate to the driver but retain a
1 ms idle-sleep fallback.
The host can instead call `poll` after its own event delivery and use the reported
deadline, or give `Driver` a notifier, an erased repeatable callable called when
an event delivered while no poll runs makes the root runnable. The notifier is
called only when the ready queue was empty and no poll is running; a poll clears
its polling flag before reading readiness, both sequentially consistent with the
queue, so either the poll reports the work or the notifier runs. `finish` stops
notifications and waits for a call in progress. Cross-thread task and payload
execution remains unqualified.

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

## Work-stealing structures

Pass 13a builds the concurrent structures of the work-stealing pool in
isolation, in the private package `fp.effects._async.scheduling`. The engine
does not use them yet. Each module documents the memory ordering of every
atomic operation and why it suffices. Elements are generic move-only values,
and each one leaves a structure exactly once or is destroyed with it.

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
  ensure that one of them sees the other, so no work is stranded.

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
