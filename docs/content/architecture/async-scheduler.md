# Wake-driven execution

The canonical wake registry and async driver implement cooperative scheduling
for `fp.effects.async_runtime`. `Driver(program, token, clock)` owns a linear task and
`poll(budget)` returns `Progress`: completion, runnable status, the earliest
live deadline, and the number of root polls and timer events performed.
`finish()` still requires complete draining. `Clock.manual()` and `advance_to()`
allow deterministic host control; default clocks use public monotonic time.

## Queue ownership

Execution slots own registrations in a shared metadata hierarchy. A node's own
readiness is distinct from its ready descendants. This distinction matters when
a child starts and parks during one enclosing poll: consuming that child's wake
must also clear inherited ancestor readiness without losing an independent
notification. Ready siblings use intrusive FIFO links; removal is O(1), and
duplicate notifications retain the existing queue position.

Fiber hosts select ready child IDs directly and count unfinished children. They do not rebuild flattened wake lists or scan parked
children on the scheduled path. Forwarding through bind, loop and callback cleanup uses the child
registration. The legacy direct-poll path retains wait descriptors. Cancellation
and error settlement remain canonical, including masked finalization.

Signal subscribers retain only metadata handles. Task generation and wait epoch
checks reject both notifications for retired storage and notifications from a
previous wait on the same live task. Registration compares the captured revision
under the signal guard. Subscriptions are removed on polling and completion.
The shared cancellation token emits the same notification on its first request;
its atomic requested flag remains the source of cancellation state.

Timers use the standard library `BinaryHeap`. Stale generations are discarded
before reporting a deadline; heap rebuilding bounds retained entries to twice
the live timer count plus 32. Node and subscriber storage is reused and bounded
by peak simultaneous registrations. There is no type-erased computation storage.

## Driver bounds

The nonblocking driver never calls the host-idle helper. Its budget limits root
polls plus timer events and alternates ready work with due timers. User polls,
notification fanout, and heap maintenance are not preempted or bounded by an
instruction count. All clocks propagate through masks and child contexts.

The public `run` and internal `run_pair` delegate to the driver but retain a
1 ms idle-sleep fallback.
The host can instead call `poll` after its own event delivery and use the reported
deadline. Cross-thread task/payload execution remains unqualified.

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
  stripes, each a standard-library `Deque` guarded by the shared metadata lock
  from `fp._internal.cells`, with a published length per stripe so consumers
  skip empty stripes without locking.
- **Timer heap** (`_TimerHeap`), after `TimerHeap`: changed only by its owner.
  Any thread may cancel through a generation-checked ticket (the wake
  registry's `_Ticket`), which marks and counts the node; the owner packs once
  counted cancellations reach half the heap. Other workers take expired timers
  by walking the heap. Upstream clears callbacks with plain writes and
  tolerates a duplicate run. Here a single compare-exchange on each node's
  state word picks the one taker of a move-only payload. Slots, payloads and
  heap entries live in chunks that never move, so no reclamation scheme is
  needed.

Cross-thread operations borrow a structure immutably and change only atomics
and the slots they have claimed. Mojo cannot express a victim and an exclusive
destination borrowed from the same collection, so `steal_into` relies on the
protocol rather than the borrow for `dst`.

The clients `wstp_queues` and `wstp_timers` check exact single-thread
contracts, then run several threads with tracked elements to prove that each
element is received at most once (exactly once when drained) and destroyed
once, including leftovers. Measurements from `probes/wstp_cost.mojo` at O3 on
a 4-core x86 host:

| Operation | ns |
|---|---|
| Acquire load, release store, relaxed load (plain-load cost) | 0.4–0.7 |
| `fetch_add`, compare-exchange, sequential store, sequential fence | 6–9 |
| Ring enqueue and dequeue pair | 14 |
| Stolen element, or element spilled to the external queue | 17–19 |
| External push and pop pair (`_lock_metadata`) | 77–81 |
| The same pair under a borrowed spin lock | 25 |
| Timer insert and poll with 1,000 timers queued (`BinaryHeap`: 45–60) | 58–61 |
| Timer insert and owner cancellation, or marked cancellation | 24–35 |

Under contention, an owner's ring pair costs about 350 ns while two thieves
steal in a tight loop, and an external pair costs 1.5 µs with four threads on
four stripes. The shared lock calls `sleep(0.0)` between attempts; how much of
that cost the sleep accounts for has not been measured.
