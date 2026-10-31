# Async fibers

`io.start()` runs an `IO` as a fiber beside the program that started it, its
owner, and returns a `Fiber[T, E]` handle. The [application guide](../guides/async-runtime.md#run-work-beside-its-owner)
states the contract; this page describes how the runtime keeps it. The
[advanced plan](async-advanced-plan.md#pass-9-progress) records how fibers were
built and measured. Fibers replaced the private nursery, which admitted a
lifetime-bounded number of children of one machine type.

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
