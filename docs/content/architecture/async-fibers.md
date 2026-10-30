# Async fibers

`io.start()` runs an `IO` as a fiber beside the program that started it, its
owner, and returns a `Fiber[T, E]` handle. The [application guide](../guides/async-runtime.md#run-work-beside-its-owner)
states the contract; this page describes how the runtime keeps it. The
[advanced plan](async-advanced-plan.md#pass-9-progress) records how fibers were
built and measured. Fibers replaced the private nursery, which admitted a
lifetime-bounded number of children of one machine type.

## Hosting and scheduling

The entered `IO` whose run loop executes the first `start` becomes a host. It
creates an inbox, shared by every run loop it hosts, and a table of fiber slots.
A start reserves a slot in the inbox, builds the child's own run loop with that
slot as its fiber id, and queues it with a new shared record. The host admits
queued children into its table after each poll of its own program or a fiber, so
fibers started by fibers land in the same flat table, owned by the fiber that
started them. Nested fibers therefore cost no native stack. The sides of `both`
and the races are fibers too; an `IO` lifted into a leaf with `IO.lift` is its
own host.

Each fiber is a canonical execution slot polling its run loop as an erased leaf,
registered under the host's wake node with tag `i + 1`; the host program's own
leaves keep tag 0. The host runs its program inline and ticks ready fibers while
the root transition budget lasts, each at most once per poll, passing over the
program's leaf in the ready queue. Whether fibers or the program run first
alternates with each poll, so neither starves the other. Completed slots return
to the inbox's free list: a million sequential start/join cycles use one slot.

`src/fp/effects/_async/fibers.mojo` owns records, inboxes, tables, and the join
and cancel leaves; `engine.mojo` adds `Fiber`, `start`, and the hosting step.
Module imports stay acyclic.

## Ownership and draining

A handle and its child share a record typed only by `E`: the child's
cancellation token, a completion signal, and the settled outcome. A success
stays erased until `join` takes it as `T`, so the host never names `T` and can
destroy an unjoined success through its erased owner.

When a fiber's program is terminal, it cancels its live children and holds its
outcome until they complete; the host completes once its program is terminal and
its direct children are done. Completion publishes the outcome, notifies the
signal, and releases an owner that was waiting only for that child; the cascade
is iterative. A child canceled before its first poll runs nothing, through the
slot's entry checkpoint.

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

`Supervisor[E].scoped(body)` starts a parked supervisor fiber in the calling
fiber's host, owned by the caller, and runs the body on the caller's run loop.
`supervise(io)` queues `io` in that host with the supervisor fiber as its owner,
so the fiber that called `supervise` can finish without draining it. Release is
the body's finalizer: it stops the parked program, and the host's owner draining
cancels the supervised fibers and completes the supervisor only after they
finish; awaiting release first waits for them. A `Resource` cannot host a
supervisor, because its phases run as nested `IO`s that drain their own fibers.

## Diagnostics

`Driver.fibers()` lists the root `IO`'s live fibers between polls: each entry's
slot, its owner's slot, and whether it is runnable, suspended, or draining its
children. It holds no payloads or completed fibers, and fibers hosted by an `IO`
lifted into a leaf are not listed. Slots are reused, so an index is not an identity.

## Qualification

`fiber_basics`, `fiber_drain`, `fiber_reporting`, `fiber_churn`, and
`fiber_snapshot` cover progress, joins, cancellation, draining, reporting,
storage reuse under a 1 MiB stack, and snapshots. `public_reject_fiber_moved`
and `public_reject_fiber_error` reject a join of a moved handle and a child with
another error type. The scheduler, coordination, erased-storage, and workload
clients run their dynamic children as fibers.
