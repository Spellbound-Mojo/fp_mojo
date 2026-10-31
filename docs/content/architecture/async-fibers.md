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

The right to an outcome is one claim. The handle holds it, `join` moves it into
the join leaf, and the leaf moves it with the outcome into a delivery that the
join's own map frame unwraps. A canceled joiner's leaf takes nothing. If a
handoff observes cancellation between the leaf and that frame, dropping the
delivery returns the outcome to the record.

Dropping the last claim releases the record. A released failure goes to the
runtime's reporter at once, or when the child completes; a released success is
destroyed. So each failure is joined or reported exactly once. The root's
`IORuntimeConfig` supplies the reporter and whether reporting is on, and each
record copies them on admission. `IOContext` carries the running fiber's
identity, so the join leaf aborts a direct self-join.

## Supervisors

`Supervisor[E].scoped(body)` starts a parked supervisor fiber owned by the
caller's run loop and runs the body on that loop. `supervise(io)` starts `io`
with the supervisor fiber's scope as its owner, so the fiber that called
`supervise` can finish without draining it. Release is the body's finalizer: it
stops the parked program, and the supervisor fiber's task, as any owner,
cancels the supervised fibers and completes only after they finish; awaiting
release first waits for them.

## Diagnostics

`Driver.fibers()` lists the live fibers under the root between polls, from the
executor's table of live fibers' metadata: each entry's slot, the slot of the
fiber whose run loop started it (0 for the root program), and whether it is
runnable (scheduled), suspended (idle), or draining its children. The table
holds no payloads, and a task leaves it when it completes. Fibers started by an
`IO` lifted into a leaf are listed under the fiber running that leaf. Slots are
reused, so an index is not an identity.

## Qualification

`fiber_basics`, `fiber_drain`, `fiber_reporting`, `fiber_churn`, and
`fiber_snapshot` cover progress, joins, cancellation, draining, reporting,
storage reuse under a 1 MiB stack, and snapshots. `public_reject_fiber_moved`
and `public_reject_fiber_error` reject a join of a moved handle and a child with
another error type. The scheduler, coordination, erased-storage, and workload
clients run their dynamic children as fibers.
