# Deterministic async worker workload

The `workload` qualification client assembles a bounded pipeline from the private
runtime's existing operations. A producer transfers six move-only requests
through a queue of capacity two. Six nursery children each acquire one of two
semaphore permits, take a request, and execute a scoped callback operation with
a timeout and fallback. The scope retains its request through callback withdrawal;
the worker retains its permit until the complete operation finishes.

The host drives seven scheduling operations per iteration, delivers callback
results, releases withdrawal gates after three observations, and advances a manual
clock. It never sleeps. The workload repeats four scenarios eight times:

- All callbacks complete and return their results.
- One callback times out; its fallback starts after withdrawal and request release.
- Callback withdrawal fails; structured ownership drains the remaining workers.
- The parent is canceled with both permits occupied; entered work fully drains.

The timeout scenario advances the clock after the other five requests drain.
Advancing a shared clock while several operations are still in cleanup would
legitimately expire their deadlines too; this fixture isolates the intended
single timeout explicitly.

Each cycle checks exact request destruction, two permits restored, at most two
active callbacks, expected results/errors/cancellation, rejected late callbacks,
and removal of callback, withdrawal, task, and timer registrations. Registry
storage must remain within the finite workload bound. Progress is bounded to
2,000 host iterations. This is a deterministic integration test, not a throughput
benchmark or evidence of parallel thread execution.

The client uses existing runtime interfaces without changing runtime code. Its
four-way source/package O0/O3 matrix is part of the maintained qualification
inventory. A focused run uses `qualify.py --client workload`; its report identifies
the selected scope explicitly. The composed client has a 360-second compile
budget and retains the 15-second execution limit.

`qualification-workload-1` passed all four selected source/package O0/O3 checks
and both package builds on pinned Mojo 1.2.0. Every executable completed all 32
cycles. Input-stability, artifact/diagnostic audits, and documentation checks
passed. This pass changes the integration client and qualification inventory;
it does not change runtime implementation.
