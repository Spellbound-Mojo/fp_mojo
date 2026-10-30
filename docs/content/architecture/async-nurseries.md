# Dynamic typed nurseries

Status: private since Pass 8a. `Nursery` and `Spawner` left the public API when
it switched to `IO`; [Pass 9 fibers](async-advanced-plan.md#pass-9-proposal)
replace them with `start` and `join`, and generalize the storage described here.

The private `Nursery` owns runtime admission and joining of typed children. It preserves native Mojo types and origins, cooperative polling, and
complete draining of entered work. The [scheduler](async-scheduler.md) selects
ready children without scanning parked work; [coordination](async-coordination.md)
provides reusable queues and permits.

## Contract

`Nursery[P](limit)` owns a runtime-sized group of one exact machine type `P`.
`spawner()` returns a copyable submission handle. `try_spawn(child)` transfers a
child on success (`None`) or returns the original unentered recipe on rejection
(`Some(child)`). Handles may be retained after the nursery finishes; subsequent
submissions are rejected. They are not child-task owners or detached join handles.

The nonnegative limit bounds **total accepted children**, including queued,
active and completed children. It is not a reusable concurrency permit. Results
and terminal slots remain owned until joining, so this explicit limit bounds
registry size. Value and error payload sizes are still controlled by the caller.
Heterogeneous work can compose through typed `both` groups or an explicit common
machine type; the nursery does not erase unrelated machine types.
Admission accepts `Machine`; a dynamic `ScopedMachine` nursery remains separate.
An enclosing `Scope` can retain its resource while these owned children drain.

Admission remains open until `close()` or observed parent/child cancellation or
failure. Closing normally allows all accepted children to finish. Failure or
cancellation closes admission and requests cancellation of unfinished children,
including queued children before entry. Every entered child drains before the
nursery returns. Dropping an unopened nursery closes retained handles and drops
only unentered children. A linear `Driver` owns entered execution.

Children have independent, initially unmasked tokens. The parent's mask controls
whether its own request is observed. Shared child storage and draining policy
also serve fixed pairs, while canonical `_finish` owns error accumulation.
Successful results and failures follow admission order, independently of actual
completion order. Cancellation remains independent of failure.

## Scheduling and ownership

Each poll admits at most one queued child and polls at most one ready child.
After admission closes and all children finish, each poll collects one terminal
outcome. The scheduled path uses FIFO ready-child metadata and does not scan
parked children. Blocking convenience runners still use a 1 ms idle-sleep fallback.

The admission signal revision is read before the queue snapshot. Every accepted
submission and closure wakes the owner; waiting also includes each active child's
actual wake conditions. A delivered parent cancellation does not keep masked
child cleanup runnable. All user polling and payload destruction occurs outside
the shared admission guard.

The contract is cooperative and single-threaded. Native captured origins remain
part of `P`, the nursery, the submission handle, and the resulting values/errors.
Execution uses the canonical pure-Mojo runtime; it provides no OS event
integration or cross-thread payload execution guarantee.

## Qualification

Qualification covers admission after the owner parks, interleaved producer and
children, bounded admission with ownership-preserving rejection, retained handles,
normal closure, parent masking/cancellation, failure-driven closure, queued-child
skipping, out-of-order cleanup, task movement and deterministic error order.
Borrowed value/error checks and compiler rejection fixtures cover origin escape
and incompatible submissions. Existing pair, scope, callback and coordination
clients remain in the four-way source/package O0/O3 matrix.

The queue extraction primitive is shared with canonical synchronous coordination;
its existing clients are included because that internal helper was generalized.

The [overnight worker workload](async-qualification.md) repeatedly exercises
normal closure, timeout, cleanup failure and parent cancellation. Serial
performance diagnostics also check idle driving and cancellation with up to
512 sleeping children. Nursery admission remains a lifetime bound, not a
reusable concurrency permit.
