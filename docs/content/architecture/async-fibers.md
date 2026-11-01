# Async fibers

`io.start()` runs an `IO` as a fiber beside the program that started it, its
owner, and returns a `Fiber[T, E]` handle. The [application guide](../guides/async-runtime.md#run-work-beside-its-owner)
states the contract; this page describes how the runtime keeps it. Fibers
replace the former private nursery, admitting arbitrary concurrent child tasks
with constant native stack and structured ownership.

## Tasks and scheduling

Every fiber is a task of its root's executor, and so is the root program. A
task is a header with an atomic scheduling state (idle, scheduled, running,
notified while running, done) and its owned body; a ready-queue entry is the
right to run it, and only the executor holding that right touches the body.
`src/fp/effects/_async/executor.mojo` owns the current-thread executor, the
profile `Driver`, `run`, and `TestControl` use: one root poll is one executor
turn, which runs queued tasks in FIFO order, each at most once, while the root
transition budget lasts. A task requeued during a turn waits for the next one,
so the order is deterministic. The queue sits behind a small interface that a
work-stealing worker's queues can implement later.

Each fiber has its own [wake registry](async-scheduler.md): its run loop's slot
is registered at the registry's root, and every leaf the fiber polls registers
beneath it. When a wake makes the root's ready list non-empty, the registry's
hook moves the task from idle to scheduled and queues it, or marks a running
task notified. When a run ends, the task is requeued if anything in it is ready
and becomes idle otherwise; the decision is taken under the registry's lock,
which every wake takes before its hook, so no wake is lost.

`io.start()` queues the child on the starting run loop, which admits it when
its current run segment ends: the child gets its own token, registry, and
diagnostic slot, and its slot's first registration is ready, so it runs in a
coming turn. Nested fibers therefore cost no native stack. The sides of `both`
and the races are fibers too, and so are fibers started by an `IO` lifted into
a leaf: they run on the same executor as every other fiber of the root.

`src/fp/effects/_async/fibers.mojo` owns records, scopes, fiber tasks, and the
join and cancel leaves; `engine.mojo` adds `Fiber`, `start`, and admission.
Module imports stay acyclic.

## Ownership and draining

A handle and its child share a record typed only by `E`: the child's
cancellation token, a completion signal, and the settled outcome. A success
stays erased until `join` takes it as `T`, so the runtime never names `T` and
can destroy an unjoined success through its erased owner.

A run loop's started fibers belong to its ownership scope, which counts its live
children atomically and keeps their records. A fiber's own run loop owns the
scope of its record: when the fiber's program is terminal, its task holds the
settled outcome, cancels the scope's live children, and waits on the scope's
signal until the count is zero. An `IO` polled as a leaf, including the root
program, drains the scope of its own run loop in the same way before it
completes, so a program with another error type, which runs as a leaf, still
drains the fibers it started. Completion publishes the outcome, notifies the
record's signal, decrements the owner's count, and wakes the owner when it
reaches zero; owners are separate tasks, so no completion cascades natively. A
child canceled before its first poll runs nothing, through the slot's entry
checkpoint. Completed tasks drop their bodies at once, and diagnostic slots are
reused: a million sequential start/join cycles use one slot.

## Joins and failures

The outcome lives in a lock-free one-shot slot (`src/fp/_internal/oneshot.mojo`):
the fiber's task is its only writer, and the right to the outcome is one claim.
The handle holds the claim, `join` moves it into the join leaf, and the leaf
takes the published outcome in the same atomic step that consumes the claim,
into a delivery that the join's own map frame unwraps. A canceled joiner's leaf
takes nothing. If a handoff observes cancellation between the leaf and that
frame, the dropped delivery disposes of the outcome itself.

Dropping the last claim releases the record. Exactly one party disposes of an
outcome nobody joins, decided by one compare-exchange on the slot's state: the
release, when the outcome is already published, or the completing task, when
the release came first. A disposed failure goes to the runtime's reporter on
that party's thread; a disposed success is destroyed. So each failure is joined
or reported exactly once. The root's `IORuntimeConfig` supplies the reporter
and whether reporting is on, and each record is created with them, before its
handle exists. `done` is a lock-free acquire load of the slot's state. `IOContext` carries the running fiber's
identity, so the join leaf aborts a direct self-join.

## Supervisors

`Supervisor[E].scoped(body)` starts a parked supervisor fiber owned by the
caller's run loop and runs the body on that loop. `supervise(io)` starts `io`
with the supervisor fiber's scope as its owner, so the fiber that called
`supervise` can finish without draining it. A scope lists its children on a
closable lock-free stack (`src/fp/_internal/closable_stack.mojo`); adoption
pushes unless the stack is closed. Release is the body's finalizer: it closes
the supervisor's stack with one atomic step and cancels the live children, or,
awaiting release, waits for the scope's live count to reach zero; then it stops
the parked program, a `CancellationToken`, and waits for the supervisor fiber,
whose task drains its scope as any owner does. A `supervise` refused by the
closed stack completes its record canceled at once, and its program never runs.
An owner's drain closes its own scope the same way before canceling.

## Diagnostics

`Driver.fibers()` lists the live fibers under the root between polls, from the
scheduler's lock-free diagnostic slots (`src/fp/_internal/fiber_slots.mojo`):
each slot's index, the slot of the fiber whose run loop started it (0 for the
root program), and whether it is runnable (scheduled), suspended (idle), or
draining its children. A fiber takes a slot from a lock-free free-index stack
when it is admitted and returns it when it completes; no lock is taken. Slots
hold no payloads. The snapshot reads live tasks' states, so it runs only
between polls on the driving thread. Fibers started by an
`IO` lifted into a leaf are listed under the fiber running that leaf. Slots are
reused, so an index is not an identity.

`Runtime.fibers()` merges the tables of every root running on a runtime,
numbering each root in `FiberInfo.root`. A runtime's roots create their
tables shared, so a snapshot may run from any thread while their fibers run:
a reader count makes a finishing fiber wait for snapshots in progress before
its task state can be freed (see the scheduler page's
[runtime](async-scheduler.md#the-runtime)).

## Allocation ownership

The runtime avoids pooling, keeping prompt reclamation predictable and bounded.
The probes are `experiments/async-state-machines/probes/storage_cost.mojo` (allocations and
time per operation) and `diagnostics_cost.mojo`. `probes/alloc_counter.c` counts
heap allocations: Mojo's heap is tcmalloc behind
`KGEN_CompilerRT_AlignedAlloc` and `KGEN_CompilerRT_AlignedFree`, which the
preloaded counter wraps, attributing each allocation to its call site.

### Allocations per operation

Allocations per operation, from `storage_cost` at O3 through one `Runtime`;
every case frees exactly what it allocates. A frame's bytes are the growth of
the run loop's frame stack, amortized:

| Operation | Current thread | Work-stealing pool |
|---|---:|---:|
| `flat_map`, `map`, `handle_error_with` frame, built and run | 0 | 0 |
| Loop step through `flat_map` (tail recursion) | 0 | 0 |
| Nested `defer` level | 0 | 0 |
| `guarantee` frame: build, then run | 1, then 2 | 1, then 2 |
| Fiber start and join | 28 | 29 |
| Callback completion (`IO.async_`, completed at once) | 9 | 9 |
| `par_traverse` element | 22 | 23 to 24 |
| Blocking call | 15 to 19 | 16 to 17 |
| Root (`Runtime.run` of a pure program) | 18 | 29 |

Binds, maps, recoveries, `defer` levels, and loop steps allocate
nothing: small values and callbacks live inline, and frames go on the run loop's frame stack, a list whose growth
amortizes to about 126 bytes per frame of a runtime-built chain; a
tail-recursive loop retains nothing. Allocation follows owners instead.

A fiber start and join allocates once for each of about fifteen owners, each
with its own type, size and lifetime:

- the fiber record, its cancellation token, and the token's and the record's
  signals;
- the child's ownership scope, its closable stack and its signal;
- the child's wake registry (`_Runtime.fork`);
- the run loop's spawn request and the erased boxes of the start, the step
  and the join leaf;
- the kernel slots of the child and of the join.

A root adds its scheduler, its executor, its fiber table and a ready queue.
Each allocation is freed when its owner is: completed work retains nothing.

### Pooling

Pooling is not adopted. On the session host, at O3 without the counter:

- A 64-byte allocation and its free cost about 30 ns. Mojo's heap is
  tcmalloc, whose per-thread free lists by size class already do what a
  typed pool would.
- A fiber start and join takes about 6.8 µs on the current thread and
  6.9 µs on the pool. Its 28 allocations cost at most about 0.85 µs, or 12%,
  and pooling could remove only part of that: a free-list pop and push saves
  only its difference from tcmalloc's fast path.
- The frame paths that dominate long programs allocate nothing, so there is
  nothing to pool there.
- One pool per owner would need, for each of about fifteen types, prompt
  reclamation in long-lived roots, exact destruction, alignment, origins,
  isolation from retained joins and diagnostics, and on the pool a return path
  for storage freed on another worker. That is a parallel lifetime mechanism,
  which the runtime adds only when measurements justify it.

The simpler representation stays. If start cost matters later, the lever is
fewer allocations: placing owners that share a lifetime in one allocation,
as the work-stealing pool already does with a task's atomics and the
record's one-shot slot. That change keeps each owner's destruction, and needs
no pool.

### Long-lived roots

`storage_soak` runs rounds of twelve programs through one `Runtime`:

- sequential start/join churn, a burst of 32 live fibers, and a parked
  fiber canceled and joined;
- a sleep, and a timeout that cancels its loser's timer;
- `par_traverse` over 16 children;
- a blocking call returning a tracked payload;
- a failing root, a failing fiber's join, an unjoined failure reported once,
  an `attempt`, and a race whose slow side is canceled.

Every round checks each value, exact destruction of every tracked payload,
one report per unjoined failure, and that `Runtime.fibers()` is empty. Run
for 30 minutes with the counter preloaded (O0, the session host, both soaks at
once):

| | Current thread | Work-stealing pool (4 workers) |
|---|---:|---:|
| Programs | 2,707,884 | 1,265,256 |
| Live Mojo allocations | 5 at 1 s, then 7 throughout | 172 at 1 s, 178 from 5 min to the end |
| Resident set | 12.96 MiB at 1 s, 13.03 MiB at 30 min | 14.87 MiB at 1 s, 22.1 at 5 min, 25.12 at 20 min, 25.16 at 30 min |

Completed programs retain nothing: after warm-up the count of live
allocations, which is exact, does not move. On the current thread the
resident set is flat. On the pool it grows while live allocations do not,
in steps that slow down: 0.04 MiB over the last 10 minutes. The growth
comes with parallelism. Over five minutes run side by side, a one-worker pool
grew 0.2 MiB (13.68 to 13.88 MiB) and a four-worker pool 3.9 MiB (15.05 to
18.94 MiB), each with constant live allocations and thread counts. That fits
tcmalloc's per-thread caches keeping storage that one worker allocated and
another freed, a bounded cache, not retained work.
The overnight soak in the long runs extends this to hours.

### Diagnostics overhead

Slot publication costs about 30 ns per fiber: one `register` when the fiber
is admitted and one `release` when it finishes. That is 0.4 to 0.5% of a
fiber start and join (6.7 to 7.4 µs in the same runs). A table created
shared for `Runtime.fibers()` adds 0 to 6 ns for the release's sequentially
consistent clear and its load of the reader count.

| Measurement (O3, `diagnostics_cost`) | Current thread | Pool |
|---|---:|---:|
| Slot register and release, unshared table | 29.5 ns | 31.6 ns |
| The same, shared table | 35.8 ns | 31.3 ns |
| The same, shared, another thread snapshotting in a loop | 454 ns | 469 ns |
| `_FiberSlots.snapshot()`, shared, empty | 18 ns | 19 ns |
| `_FiberSlots.snapshot()`, 1,024 slots | 2.2 to 5.0 µs | 2.7 to 4.6 µs |
| `Driver.fibers()`, 1,000 parked fibers | 12.3 µs | 6.5 µs |
| `Runtime.fibers()`, 1,000 parked fibers | 13.5 µs | 8.5 µs |
| Start and join, nobody snapshotting | 7.4 µs | 6.7 µs |
| The same, `Runtime.fibers()` once per millisecond | 6.6 µs | 6.2 µs |
| The same, `Runtime.fibers()` in a loop on another thread | 10.1 µs | 9.5 µs |
| Fiber pair, nobody snapshotting | 12.6 µs | 10.3 µs |
| The same, `Runtime.fibers()` in a loop on another thread | 16.2 µs | 15.3 µs |

The `Driver.fibers()` and `Runtime.fibers()` rows were measured on different
runs of the same code, so the profiles' difference is host noise.

- **Snapshots.** A snapshot costs about 5 to 13 ns per live fiber, list
  building included, plus about 18 ns for the shared table's reader count.
- **Occasional snapshots** cost nothing measurable. One `Runtime.fibers()`
  per millisecond leaves start and join within run-to-run noise.
- **A snapshot loop on another thread** slows starts and joins by about 40%,
  and fiber pairs by about 30 to 50%. Each release then meets a snapshot in
  progress, waits for it to finish, and the reader count's cache line moves
  between the two threads.

The reader count is the documented cost of snapshots from any thread
(`fiber_slots.mojo`): it delays completion only while snapshots run, and a
monitor that snapshots periodically does not pay it.

### Bounded stack on both profiles

`stack_profiles` runs the same programs on the current-thread profile,
through a `Runtime` on the calling thread, and on a four-worker pool whose
worker threads have 1 MiB native stacks. Each program first checks the stack
of the thread running it. The programs:

- a million-bind runtime-built chain;
- a million nested `defer` levels;
- a failure crossing a million binds to its recovery;
- a failure crossing a million nested finalizers;
- a fiber parked under a million frames, canceled and joined;
- an unopened million-step chain, disposed of on the thread that runs the
  program;
- the chain in a started fiber.

On the pool, a root parked under a million frames is also canceled from the
main thread through its token. Qualification runs the client again under
`ulimit -s 1024`, so the calling thread has 1 MiB too.

The workers' stack size is private. `_Pool` takes `stack_bytes`, which
`OSThread` sets through a pthread attribute; 0 keeps the system default,
which glibc takes from `RLIMIT_STACK` at process start. Threads of the
blocking hand-off's cache keep the default. All of it passes at O0 with
128 KiB worker stacks as well. With 64 KiB it fails in a call chain about
twenty frames deep, not in a deep recursion: the program's depth costs no
native stack, and the margin is the size of O0's frames.

## Qualification

`fiber_basics`, `fiber_drain`, `fiber_reporting`, `fiber_churn`, and
`fiber_snapshot` cover progress, joins, cancellation, draining, reporting,
storage reuse under a 1 MiB stack, and snapshots. `public_reject_fiber_moved`
and `public_reject_fiber_error` reject a join of a moved handle and a child with
another error type. The scheduler, coordination, erased-storage, and workload
clients run their dynamic children as fibers. `race_oneshot`, `race_stack`,
`race_record`, `race_supervisor`, and `race_registrations` drive the one-shot
slot, the closable stack, the record's protocol, scope adoption against
release, and the registration count from several OS threads, with ledgers that
prove each value is destroyed, and each failure joined or reported, exactly once.

`storage_soak` (on both profiles) and `stack_profiles` (both profiles in one
client, also under a 1 MiB stack) qualify the
[allocation ownership](#allocation-ownership) results. In qualification,
`storage_soak` runs 300 rounds and fails if the resident set grows by more
than 8 MiB after its first 100 rounds; given a duration, it soaks for that
long and logs one sample per second.
