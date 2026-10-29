# Dynamic typed nurseries

This pass extends the private [callback and state-machine runtime](async-callbacks.md)
with runtime admission of children. It retains native Mojo types and origins,
cooperative polling, and complete draining of entered work.

The later [scheduler pass](async-scheduler.md) replaces the readiness scans
described at this milestone, and [resumable coordination](async-coordination.md)
adds notification-based Deferred, Queue, and Semaphore operations.

## Contract

`Nursery[P](limit)` owns a runtime-sized group of one exact machine type `P`.
`spawner()` returns a copyable submission handle. `try_spawn(child)` transfers a
recipe on success (`None`) or returns the original unentered recipe on rejection
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
only unentered recipes. A linear `Task` owns entered execution as before.

Children have independent, initially unmasked tokens. The parent's mask controls
whether its own request is observed. Shared child storage and draining policy
also serve fixed pairs, while canonical `_finish` owns error accumulation.
Successful results and failures follow admission order, independently of actual
completion order. Cancellation remains independent of failure.

## Scheduling and ownership

Each poll admits at most one queued recipe and polls at most one ready child.
After admission closes and all children finish, each poll collects one terminal
outcome. At this milestone, selection rotated through children, and readiness
scans and wait unions cost O(accepted children). The current scheduled path uses
FIFO ready-child metadata and does not scan parked children. Blocking convenience
runners still use a 1 ms idle-sleep fallback.

The admission signal revision is read before the queue snapshot. Every accepted
submission and closure wakes the owner; waiting also includes each active child's
actual wake conditions. A delivered parent cancellation does not keep masked
child cleanup runnable. All user polling and payload destruction occurs outside
the shared admission guard.

The contract is cooperative and single-threaded. Native captured origins remain
part of `P`, the nursery, the submission handle, and the resulting values/errors.
No origin erasure, C backend, private coroutine primitive, OS event integration,
or public async API is introduced.

## Acceptance gates

Qualification covers admission after the owner parks, interleaved producer and
children, bounded admission with ownership-preserving rejection, retained handles,
normal closure, parent masking/cancellation, failure-driven closure, queued-child
skipping, out-of-order cleanup, task movement and deterministic error order.
Borrowed value/error checks and compiler rejection fixtures cover origin escape
and incompatible submissions. Existing pair, scope, callback and coordination
clients remain in the four-way source/package O0/O3 matrix.

The queue extraction primitive is shared with canonical synchronous coordination;
its existing clients are included because that internal helper was generalized.

## Qualification results

On Linux x86-64 with Mojo **1.2.0 (2016d0cd)**, the complete gate passed
**132/132** source/package O0/O3 checks, both package precompilations, and
**12/12** additional executions under a 1024 KiB stack limit. Input stability,
diagnostics, executable hashes and artifact audits passed. The documentation
build and link/export inventory passed as well.

Evidence is retained in
`.cache/state-machine-foundation/qualification-nurseries-1/report.json`.
The suite includes 11 positive experiment clients, 15 compiler rejection clients
and seven existing resource/finalization/coordination clients. No full-repository
suite, throughput benchmark or cross-thread qualification was run.

Reproduce from the repository root in its pinned Pixi environment:

```sh
pixi run python experiments/async-state-machines/qualify.py \
  --output .cache/async-nursery-check --jobs 4
```

Use a fresh output directory. The scheduler pass now supplies event-driven
wakeups; OS I/O integration remains future work. This milestone establishes
dynamic ownership and joining semantics.
