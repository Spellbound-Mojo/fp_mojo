# Async public API readiness review

The implemented package is a qualified private foundation for cooperative async
work in pure Mojo. The review recommends defining a supported namespace and
user contract before promoting exports. This pass performs that review; it does
not silently make experimental interfaces public.

## What the implementation establishes

- Typed sequencing, iterative loops, fixed child pairs, and bounded dynamic
  nurseries preserve native values, errors, ownership, and external origins.
- Linear Task/Driver owners require entered work to drain. Scope lends resources
  for each poll, and finalization borrows exact exits without retaining loans.
- Signals and timers drive owned, generation-checked registrations. The host
  controls bounded scheduling and can supply deterministic time.
- Callbacks own withdrawal, races drain losing children, and timeouts defer
  fallback until cleanup. Cancellation and errors remain independent.
- Deferred, queues, and permits reuse the synchronous library's canonical state
  transitions. Finalization and mask restoration also share canonical mechanisms.
- Tests exercise the pieces together in a bounded producer/worker pipeline,
  including normal completion, timeouts, cleanup failure, and parent cancellation.

## Contract decisions for a public module

A candidate namespace is `fp.effects.async_runtime`, keeping its Machine-based
constructors separate from synchronous ReaderAction operations. Promotion should
choose its supported high-level constructors and deliberately identify the lower
level extension protocol. Private slots, child metadata, guarded cells, and
scheduler registrations should remain implementation details.

Race is explicitly first-terminal, including cancellation, with scheduler-order
ties. It is not a claim of complete Cats Effect compatibility. A losing child's
cancellation is normalized while its errors remain observable. Timeout denotes
a cancellation deadline, not a hard deadline for return. These semantics and
fallback admission must be documented before promising compatibility.

The public host contract should describe cooperative execution and a budget of
scheduling operations. User polls, synchronous callbacks, destructors, notification
fanout, and heap maintenance are not instruction-count bounded. Blocking helpers
retain their documented idle-sleep fallback. The inspected Mojo 1.2 public APIs
did not provide the OS parking/readiness boundary needed here; the nonblocking
host driver can still be embedded without that backend.

Queue values are FIFO; semaphore/queue waiter fairness is not promised. Nurseries
bound total accepted children, including retained results, rather than supplying
a reusable concurrency permit. Native types remain part of machine types; dynamic
heterogeneous admission requires an explicit native representation. Scoped borrows
of resources and exits use immutable origins and last one poll. A mutable scoped
interface would need its own explicit contract. Raw custom Machine implementations
must obey completion and cancellation rules; the linear host owner cannot make
arbitrary user code safe.

## Remaining qualification before a supported release

Current qualification targets pinned Mojo 1.2 on Linux x86-64, with source and
separate-package imports at O0/O3, exact diagnostics, ownership/origin rejection,
and bounded-stack iteration checks. This does not qualify other platforms or
parallel execution of async payloads. Existing synchronous fiber regressions do
not establish that broader guarantee.

The [complete control-pass qualification](async-finalization.md#validation) passed
228 checks, both package builds, and 12 bounded-stack executions, including the
integration workload and synchronous regressions.

Public promotion should include representative client ergonomics, a compatibility
policy, an installation/import example, and workload performance/allocation
measurements. The current correctness workload is not a benchmark. Deep concrete
machine types also have material compile costs, with explicit budgets retained
in the qualification runner; compiler and standard-library changes are outside
this project's scope.

These are library release tasks, not a requirement to wait for a compiler async
feature. The pure-Mojo foundation can continue supporting host-driven cooperative
applications while those public-contract and qualification decisions are made.
