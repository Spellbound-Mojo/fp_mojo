# Wake-driven execution

The [scheduler plan](async-scheduler-plan.md) is implemented in the private
state-machine package. `Driver(program, token, clock)` owns a linear task and
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

Nurseries select ready child IDs directly and count unfinished children. They
no longer rebuild flattened wake lists or scan parked children on the scheduled
path. Forwarding through bind, loop and callback cleanup uses the child
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

`run` and `run_pair` delegate to the driver but retain a 1 ms idle-sleep fallback.
The host can instead call `poll` after its own event delivery and use the reported
deadline. Cross-thread task/payload execution remains unqualified.

The million-iteration O0 client takes about 29 seconds in a standalone local
run with the new bookkeeping. Its execution budget is therefore explicitly
90 seconds, including the bounded-stack run; other clients retain 15 seconds.
This is a regression budget adjustment, not a throughput benchmark claim.

## Public Mojo platform investigation

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

`qualification-scheduler-1` passed **148/148 checks** using source imports and
separate package imports, at O0 and O3 with warnings as errors. Both packages
compiled, and all 12 bounded-stack executions passed. The matrix includes
deterministic scheduler tests, linear-driver rejection, and nine existing
IO, resource, coordination, and fiber regression clients. Documentation checks
also pass. This qualifies the private foundation; it does not claim a public
network backend or cross-thread task execution.
