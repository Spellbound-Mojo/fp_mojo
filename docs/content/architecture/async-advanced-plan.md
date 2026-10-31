# Advanced IO and async development plan

Status: **Passes 7a and 7b complete; Pass 8a steps 1 to 3d complete; full gates pending; [Pass 8b](#pass-8b-progress) complete; [Pass 8c](#pass-8c-progress) built; [Pass 9](#pass-9-progress) complete; [Pass 10](#pass-10-proposal) approved, in progress** ([progress](#pass-8a-progress)). The [Pass 7b proposal](#pass-7b-proposal) defines the public `IO[T, E]` surface. The [representation decisions](#representation-decisions)
were approved on 2026-10-30. This plan continues the completed foundation passes
1–6 from `nightly` commit `bda929c9bca31ed1b2311b191c9764eaac980f58`. It proposes
lightweight fibers, stack-safe general sequencing, and generic effect
capabilities. Current support remains defined by the
[async guide](../guides/async-runtime.md).

The plan is directional guidance. Pass evidence about what Mojo 1.2 supports
and what performs well may revise later passes; record such revisions here.

Concurrent collection operations are explicitly deferred: no async
`par_traverse`, `par_sequence`, or bounded concurrent collection traversal is
part of these passes. Existing validation combinators retain their meaning.

## Goals and constraints

- General lightweight fibers: start work dynamically, obtain a typed handle,
  suspend while joining, request cancellation, and await complete cleanup.
- A runtime representation that supports deep and recursively constructed
  `flat_map` programs without native call-stack growth proportional to their
  effect depth. Fixed-state `tail_rec_m` remains useful but is not a substitute
  for this goal.
- Generic programs that request the cancellation, spawning, coordination,
  timing, or callback capabilities they actually use, with native types,
  ownership, origins, and exact error admission preserved.
- One canonical execution engine and one implementation of each lifecycle
  policy. Existing resources, callbacks, races, and coordination must share
  the resulting foundation.
- Embeddable host services, explicit execution profiles, bounded diagnostic
  storage, and controllable scheduling for reproducible qualification.

Implementation prefers pure Mojo, using supported native mechanisms. Where the
standard library lacks a facility and its absence would harm users, the library
calls POSIX operating-system interfaces directly through Mojo's external calls:
to park and wake threads, wait on file descriptors, run worker threads, or read
the wall clock (decided on 2026-10-31). The library targets POSIX systems;
Linux is qualified first and macOS later. No C sources, compiler coroutine
dependency, compiler patch, or standard-library modification is planned.
Operations keep snake_case names. Through Pass 12 each root runs its fibers
cooperatively on one thread; Pass 13 adds a multi-threaded work-stealing runtime
and keeps the single-threaded one selectable. Lightweight fibers never require
one OS thread per fiber.

GPU work, concurrent collections, and a wholesale port of the Cats Effect
standard library are outside this plan. Host integration, external completion,
and blocking work are Pass 12; parallel execution contexts are Pass 13.

## What to learn from Scala Native and Cats Effect

Cats Effect is not tied to the JVM. Scala Native compiles ahead of time through
LLVM and supplies a managed runtime. LLVM compilation alone does not provide
fiber scheduling, continuation storage, or Mojo ownership proofs.
Scala Native's runtime and Cats Effect's effect runtime are separate sources of
architectural ideas; the references below distinguish those layers.

The comparison here uses Cats Effect commit
[`de84c01f76b2f42fcee9d43aba66c82992add103`](https://github.com/typelevel/cats-effect/commit/de84c01f76b2f42fcee9d43aba66c82992add103).
Its shared
[`IOFiber`](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala)
has an explicit continuation stack, finalizer stack, and run loop. Its
[native runtime bootstrap](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/native/src/main/scala/cats/effect/unsafe/IORuntimeCompanionPlatform.scala)
provides compute and blocking executors and selects platform pollers.
Older Scala Native examples describe a single-thread configuration; do not
generalize those historical limits to this source snapshot.

Borrow these architectural ideas:

| Idea | Application here |
|---|---|
| Effect evaluation separated from platform execution | Keep sequencing and cleanup independent of host parking, notification, and future device adapters. |
| Explicit continuation and finalization state | Run and unwind effects iteratively, including cancellation and disposal. |
| One owner executing a fiber at a time | Keep state transitions serialized; publish readiness through the existing scheduler. |
| Execution budgets and rescheduling | Yield between bounded interpreter transitions, with cancellation checkpoints. |
| Platform services behind contracts | Add capabilities only when a provider can implement their documented behavior. |

Do not copy Scala's `AnyRef` storage, garbage-collection assumptions, or native
FFI calls into Mojo. The transferable lesson is the execution algorithm and
separation of responsibilities. The storage representation needs its own native
Mojo ownership proof. See also the [Scala Native overview](https://scala-native.org/en/stable/).

The [implementation reference map](#implementation-reference-map) links each
pass to inspected source symbols, adaptation notes, local owners, and starting
qualification clients.

## Why arbitrary-depth flat_map is not promised today

There are two separate issues in the current representation.

**Runtime call depth.** `Bind.poll` calls `_tick` on its source or next child;
`_tick` calls that child's `poll`. A deep bind tree can therefore produce a deep
native call chain during one root poll. `OwnedPointer` indirection reduces frame
payload size, but does not turn those calls into an iterative interpreter.
Destruction of nested owned program state must also be checked independently.

**Concrete type depth.** Each bind retains its source and continuation types.
A statically nested chain produces successively larger nested type expressions.
A runtime-built chain or recursive program needs a stable carrier boundary;
moving execution to a loop alone does not solve that representation problem.

Current evidence covers 64 nested binds and a million fixed-type loop iterations
under a bounded stack. It does not establish an unlimited-depth guarantee.
This is an implementation limitation, not evidence of a fundamental Mojo or
LLVM prohibition. See the [composition contract](async-composition.md).

The target guarantee is: **runtime effect depth does not cause proportional
native call-stack growth during evaluation, suspension/resumption, error
unwinding, cancellation, or runtime-owned reclamation**. The guarantee applies
to admitted programs built through the new sequencing representation. It does
not make arbitrary recursion inside a user callback safe, make eagerly recursive
program construction lazy, promise bounded heap use, or remove compiler limits
on an explicitly enormous static type. Deferred construction must be available
so ordinary recursive effect programs do not require eager native recursion.

## Representation and execution design

The recommended direction is an iterative run loop with explicit owned frames
and a stable typed program boundary. The public result, domain error, and
retained origins remain native; private scheduling must not depend on the entire
construction history appearing in the carrier's type.

### Representation decisions

Mojo 1.2 has no existentials (its roadmap lists them as not started) and no
escaping closures (`closure-declarations.mdx`). A closed set of typed frames
cannot express runtime-built chains whose intermediate values differ in type.
The standard library erases types by hand: `_ErasedWriter` in
`std/format/tstring.mojo` stores an untyped pointer and a capture-free function
specialized for the original type, which casts the pointer back. Owning erasure
in the standard library cannot check origins either; `TaskGroup` in
`std/runtime/_asyncrt.mojo` carries an open TODO (MOCO-771) for that check.

The approved decisions are:

1. **Construction-paired erasure.** One private owner may erase an owned value.
   Each cast back to the concrete type happens only in a function specialized
   by the type that created the allocation. The owner has one allocation, runs
   the destructor exactly once through its stored destroy function, never
   exposes the raw pointer, and moves move-only payloads without copying them.
   No widened public origin, invented Send/Sync proof, or copied move-only
   payload is acceptable.
2. **Erased programs own their state.** Runtime-built chains, recursion, and
   fibers of different types need erased programs. These accept only state that
   is owned, shared through owned handles, or borrowed from origins that also
   appear in `T` or `E`; those origins remain in the carrier type. Mojo 1.2 cannot
   extract the origins a type embeds, so this is a documented precondition
   rather than a compiler check. Borrowed captures would be dangling after ASAP
   destruction, not merely unverified. Plan rule 6 (scoped borrowing into
   fibers) is therefore out of reach on 1.2. Revised on 2026-10-30: typed recipes
   are no longer a public tier; `IO[T, E]` is the one public async type (see the
   [Pass 7b proposal](#pass-7b-proposal)).
3. **Fibers and stack safety precede generic capability dictionaries.**

Hiding a type does not by itself remove recursion: an erased bind that polls an
erased source still recurses. The run loop must see the node kinds (pure, bind,
error handling, mask, finalizer, defer, leaf) and keep an explicit continuation
stack, boxing intermediate values. Existing typed combinators become leaves with
their own stack behavior until they are rebuilt on fibers. Iterative disposal
covers links the runtime owns, not programs captured inside user callbacks.

Currently every `_Slot` registers its own wake-registry node, and wakes walk all
ancestors. The new engine registers once per fiber, not once per frame.

The chosen representation must support both heterogeneous intermediate values
and heterogeneous child implementations. A homogeneous list of machines is not
the final general-fiber solution. Public recipe aliases and generic wrapper
contracts are already supported surface: changing their shape requires an
explicit migration proposal, not a silent replacement behind existing names.

Execution should advance a frame, schedule its dependency, or consume a completed
dependency, then return to the run loop. A child operation must not recursively
drive its descendants. Success, recovery, masks, resource release, and frame
disposal use the same iterative control mechanism. Native callbacks and custom
leaf polls remain cooperative boundaries and retain their own stack behavior.

The existing wake registry, generation checks, timer representation, signal
subscriptions, cancellation contexts, and outcome settlement remain canonical.
The registry currently schedules readiness; adding runnable frame ownership must
not create a second scheduler beside it. Public custom `Machine` adapters need
a documented compatibility boundary and must not inherit a false guarantee
about recursion inside their own implementations.

## Proposed lightweight fiber contract

These are semantic proposals, not finalized Mojo signatures. `Fiber` would live
in the async application namespace and would be distinct from the existing
unsafe OS-thread `fp.effects.Fiber` backend.

| Operation | Proposed behavior |
|---|---|
| `start(program)` | A deferred effect. On entry, transfer the child into the current owning scope and return a typed fiber handle. Admission and handle publication form one cancellation-safe handoff. |
| `join` | Suspend the caller without blocking its host thread; transfer the child's complete `Outcome` after all entered child cleanup finishes. Consume one exclusive right to take the result. |
| `request_cancel` | Request cancellation idempotently without waiting or consuming the result. Host and effect entry points must be distinguished in the final API. |
| `cancel` | Request cancellation and suspend until termination and cleanup. Do not consume the child's result; a retained failure remains available to join, or goes to the failure reporter. |
| `cede` | Yield a runnable fiber so other eligible fibers can progress. |
| `never` | Remain pending until cancellation can be observed. |
| `race_pair` | Return the selected outcome and the other child's handle, transferring observation rights while the owning scope still retains execution ownership. Specify cancellation-only selection and parent-cancellation cleanup before exposure. |

The proposed ownership rules are:

1. The root or explicit owning scope owns entered execution. A handle grants
   observation/cancellation rights; dropping it cannot abandon a running child
   or invoke an asynchronous destructor. Scope closure closes admission, cancels
   remaining children, and drains them. Explicit joins allow normal completion
   before scope exit. In the reviewed design the fiber that runs `start` is the
   owner, and `Nursery` and `Spawner` retire.
2. Success values and errors may be move-only. `join` cannot return the same
   owned result repeatedly or to several callers. Separate completion observers
   may share terminal status without duplicating the payload. Repeated result
   reads would require an explicitly constrained copying or sharing API.
3. Canceling a suspended joiner does not destroy its child. If the join right
   was consumed into that canceled join, result accounting returns to the
   owner. Cancellation of the owner still cancels all its children.
4. Child failure is observed through join or, if never joined, the runtime's
   failure reporter, rather than automatically failing every sibling or the
   owner. Existing `both` fail-fast policy remains an explicit consumer of the
   same lifecycle. A joined failure is transferred once; an unobserved failure
   is reported once. Cancellation-only shutdown is not fabricated into an error.
5. Completion, join publication, parent cancellation, and result observation
   have defined ordering. If cancellation prevents delivery after a result was
   removed from shared storage, transfer its failure accounting back to the
   owner and destroy any suppressed success exactly once. Do not lose errors
   or report a joined error twice.
6. Captured origins must outlive the owning execution scope. A fresh per-poll
   resource loan cannot escape into a background child. Independent external
   captures retain their origins, and resource owners cannot release while a
   child still has authorized access. Erased fiber programs follow the
   owned-state precondition in the [representation decisions](#representation-decisions).
8. Children share their owner's exact error type `E`: an `IO` chain has one
   `E`, and a program with a different error type runs as a leaf that owns its
   own children. Unobserved child failures never change the owner's outcome.
7. Runtime admission is not capped by a nursery's lifetime accepted-child count.
   Retire completed/consumed fiber storage and reuse slots with generation
   protection. Live children, unconsumed results, and retained observer handles
   still legitimately retain storage. Any admission limit must state which of
   those quantities it bounds.

Self-join, self-cancel-and-wait, scope closure during start, cancellation during
join registration, and stale handles need explicit behavior. Prefer rejecting
direct self-waits at the native setup boundary before taking ownership; indirect
dependency cycles are not promised automatic deadlock detection. Long or masked
native work can still delay cancellation indefinitely.

## Generic capability coverage

Generic programs should depend on the smallest sufficient dictionary, while
concrete application code retains its normal Pipeline syntax. Contracts belong
with the existing effect protocols; generic dispatch/lifting belongs with the
existing capability owners. They delegate to the runtime, never implement a
parallel execution engine. Preserve the algebra-to-effects dependency direction.

The following table is a coverage target. Names and module placement must avoid
collisions with the existing concrete `Async[E]`, `Clock`, and `Poll` names.

| Capability area | Required coverage |
|---|---|
| Deferred construction and errors | Native `defer`, exact callback admission, ordinary failure construction/recovery, complete outcome observation, and monadic sequencing laws. |
| Cancellation (`MonadCancel` concept) | Self-cancellation, `on_cancel`, finalization, masking, lexical restoration, and defined root cancellation behavior. |
| Spawn (`GenSpawn` concept) | Fiber creation, join/cancel, `cede`, `never`, `race_pair`, and scoped unique identities. |
| Concurrent (`GenConcurrent` concept) | Effectful `Ref` and `Deferred` creation/access, and the cancellation/spawn capabilities underneath them. This does not schedule concurrent collection operations. |
| Clock and temporal (`Clock`, `GenTemporal` concepts) | Effectful monotonic time, separate wall-clock time if supported, sleep, timeout, and cancellation-aware races. An `Instant` is not a wall-clock timestamp. |
| Synchronous suspension (`Sync` concept) | Delay/defer, clock/identity dependencies, and honest blocking/interruptible execution contracts. Supporting `delay` alone is insufficient for full coverage. |
| Asynchronous integration (`Async` concept) | Effectful callback registration, cancellation/withdrawal, execution-context access and shifting, and the required temporal/synchronous capabilities. Host-thread callback delivery alone is insufficient for full coverage. |

Cats Effect's actual inheritance is not one simple ladder: `GenSpawn` extends
`MonadCancel` and `Unique`; `GenConcurrent` extends `GenSpawn`; `GenTemporal`
adds `Clock`; `Sync` is another branch; `Async` combines `Sync` and `Temporal`.
Use that dependency structure as a reference, adapting native admission rather
than implying that the current `Async[E]` family already supplies it. See the
[Cats Effect kernel](https://github.com/typelevel/cats-effect/tree/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel).

### Resolve the error-law boundary first

Current `Async[E]` implements `Monad` and `ErrorRecovery`. Its selected failure
is `EffectFailure[E]`, which can carry cancellation. Recovery intentionally skips
canceled failures. Consequently, accepting every such failure in a generic
raise operation and expecting ordinary raise/handle laws would be incorrect.

Pass 7a must specify an ordinary recoverable error channel separately from the
complete terminal outcome. Prefer reusing the canonical nonempty error
collection and outcome owners; do not flatten away cleanup errors or clear a
cancellation flag to manufacture an instance. Compare a constrained ordinary
failure capability with a separate adapted family, and record the exact
raise/handle, attempt, and cancellation laws before implementing either.

The recommendation is to preserve full native outcomes and expose only truthful
capabilities. A dictionary that lacks a required law or operation gets a narrower
contract, not the name of a stronger Cats Effect instance. The masked
cancellation/race differences documented in [racing](async-racing.md) must be
included in this comparison. Any change to existing semantics needs a reviewed
migration or a separately named compatibility surface.

Working proposal, to verify against the raise/handle and cancellation laws: the
ordinary error channel is a failure whose `canceled` flag is false, and
`raise_error` can never set that flag. A failure with `canceled` set belongs to
the cancellation side of the outcome. Existing recovery already skips such
failures, so the mapping changes no current semantics. Cats Effect reports a
finalizer error raised during cancellation and still yields `Canceled`; this
runtime retains that error in the outcome.

Derived conveniences also require ownership review. For example, a shared
memoized result needs copying or explicit sharing, and restarting a canceled
memoized computation needs a factory that can construct fresh work. Neither is
automatically valid for a consumed recipe. Record these constraints separately
from availability of the base concurrency primitives.

### Providers and platform boundaries

Qualify a provider matrix for synchronous IO, cooperative async execution, and
small test providers. Synchronous IO must not acquire a spawn or async instance
merely because it supports delay and cancellation. Third-party providers should
compile generic clients without importing runtime internals; unsupported
capabilities should fail at their public constraint boundary.

Through Pass 12 the async provider runs each root on one thread; Pass 13 adds
a multi-threaded work-stealing runtime. Blocking, interruptible, foreign-thread,
and execution-context capabilities each come with an explicit transfer and
synchronization contract. Where the standard library lacks a facility, POSIX
interfaces are called directly, and the OS-thread code behind `unsafe_start`
becomes the one owner of thread creation. Mojo has no Send or Sync proof, so a
value that crosses threads carries a documented caller obligation. Compiler or
standard-library changes are not deliverables. If a provider is unavailable on
a platform, preserve the usable narrower profile and report the precise
outstanding capability instead of declaring full parity.

## Runtime services, scheduling, and observability

These additions strengthen the same execution architecture. They do not add
concurrent collection operations or require a second runtime.

### Embedding and host-service ownership

Define host-service contracts before adding platform providers in Pass 12;
their only consumers arrive there. An application should be able to supply scheduling and time services
without adopting a global runtime or surrendering ownership of its event loop.
Scala Native's development
[`VirtualThreadScheduler`](https://github.com/scala-native/scala-native/blob/b961982edab83915bcbbda559117f0a89d2f3e10/nativelib/src/main/scala/scala/scalanative/runtime/VirtualThreadScheduler.scala)
is a reference for an embeddable scheduling interface, not a dependency or a
claim about the stable Scala Native API.

Distinguish runtime-owned services from borrowed host services. Initialization
failure must release only resources acquired by this runtime. Shutdown closes
admission and drains entered fibers and external registrations before closing
owned notification or polling services; it must not stop an application's
borrowed executor, clock, or event loop. All retained service references must
preserve native origins. A convenience default can assemble these services
without making a global singleton part of the execution model.

### Event polling and wakeup protocols

Separate waiting for events, processing ready events, interrupting a wait, and
closing a poller. Cats Effect's
[`PollingSystem`](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/jvm-native/src/main/scala/cats/effect/unsafe/PollingSystem.scala)
provides a useful reference. The current nonblocking `Driver` and its reported
deadline remain the execution boundary; a host provider supplies waiting.

Specify readiness registration and the check-before-park handshake so a wake
between observing an empty ready queue and entering a wait cannot be lost.
Reuse signal revisions, registration generations, and wait epochs. Event
processing must distinguish a fully drained batch, more available events, and
an interrupted or expired wait. New work or an earlier deadline must trigger
the provider's wakeup protocol. External callbacks should schedule work rather
than recursively enter the interpreter.

Use controlled test providers before integrating a real platform poller. The
first poller uses POSIX `poll()` with a self-pipe, which runs unchanged on Linux
and macOS; epoll and kqueue may follow behind the same interface when
measurements justify them (decided on 2026-10-31). It replaces the idle-sleep
fallback once it meets this contract.

### Cancellation checks and yielding budgets

In Pass 8b, account for actual interpreter transitions instead of treating a root
poll as a bounded amount of nested work. Make cancellation-check frequency and
yield frequency separate policies, following the distinction in Cats Effect's
[`IORuntimeConfig`](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/unsafe/IORuntimeConfig.scala).
Validate configuration relationships so yielding cannot accidentally disable
cancellation checks.

Count continuation execution, unwind steps, and runtime-owned frame retirement.
Account separately for timer events and scheduler maintenance; do not hide an
unbounded maintenance operation behind a single cheap-looking step. Where
maintenance can be incremental, return unfinished work to the run loop.
Masked finalization may yield without becoming cancelable. Native callbacks,
custom polls, and user destructors still cannot be instruction-preempted; report
that boundary explicitly. Measure responsiveness in interpreter transitions as
well as wall-clock time under stated host conditions.

### Execution profiles and safe publication

The [Scala Native memory and threading semantics](https://scala-native.org/en/stable/user/lang.html)
illustrate why single-thread execution and shared-memory publication need
separate contracts. Define a profile matrix before Pass 12: thread-confined
interpreter state, externally shared notification state, and any future
cross-thread payload execution. One polling thread does not prove that every
handle or cancellation token is thread-confined.

Use native compile-time provider selection where it can remove unused services
without duplicating semantics. Omit synchronization only for state proven to
remain within its owning thread; preserve existing shared-state contracts.
For each supported shared boundary, specify ownership transfer, publication
ordering, the receiving thread's observation, and teardown with in-flight
producers. Readiness notification alone does not establish payload or device
memory synchronization. Unsupported profiles must fail at their public
capability boundary rather than silently select an unsafe fallback.

### Allocation ownership and prompt reclamation

Scala Native's
[`Zone`](https://github.com/scala-native/scala-native/blob/b961982edab83915bcbbda559117f0a89d2f3e10/nativelib/src/main/scala/scala/scalanative/unsafe/Zone.scala)
is a reference for explicit allocation ownership. Investigate typed frame pools
or segmented storage only after Pass 8a establishes a correct implementation and
allocation baseline. Reuse canonical allocation and slot owners rather than
introducing an independent lifetime mechanism.

Keep per-frame retirement: a single root-wide arena must not retain all
completed work until a long-lived root exits. Separate execution storage from
retained results and observer metadata so a small surviving handle does not
pin an entire completed program. Reuse storage only after native payload
destruction and release of outstanding access rights; preserve alignment,
origins, generation protection, and exactly-once destruction. Bulk memory
release is not a substitute for running destructors or draining external work.
Pass 14 records whether measured allocation cost justifies pooling and retains
the simpler representation if it does not.

### Logical fiber diagnostics

Add bounded diagnostic snapshots with the fiber implementation in Pass 9,
informed by [Cats Effect fiber dumps](https://typelevel.org/cats-effect/docs/core/fiber-dumps).
Native call stacks alone do not explain suspended fibers. Snapshots should
identify a fiber and its owner, execution phase, wait reason or join target,
deadline, cancellation/mask state, cleanup phase, and last progress. Optional
labels and a bounded transition trace can provide context without exposing
private machine layout.

Diagnostic records must not retain user payloads, callbacks, resource loans,
or completed execution graphs. Use generation-aware metadata and bounded trace
storage; distinguish terminal retained results from live execution. Define the
consistency of a snapshot and measure instrumentation overhead. Diagnostics
should explain a stalled shutdown or dependency cycle, without promising
automatic deadlock detection or retaining unbounded histories.

### Controllable test scheduling

Extend manual time into a controllable test host using the same interpreter and
scheduler mechanisms. The [Cats Effect test runtime](https://typelevel.org/cats-effect/docs/core/test-runtime)
is the reference for making time and execution progress testable without real
sleeps. Develop these controls alongside Passes 8–11 and qualify them in Pass 14.

Allow single-step execution, controlled external event delivery, and virtual
time advancement when runnable work is exhausted. Retain seeds or explicit
event/choice traces to reproduce start/join/cancel races. Explore only choices
left unspecified by the contract and permissible external event orderings;
do not randomize away promised FIFO behavior. Record enough runtime configuration
and input identity for the existing evidence auditor to replay a failure.

Distinguish quiescence awaiting external input from successful completion or a
proven deadlock. These checks complement sustained stress, retained-storage
qualification, and real provider tests; simulated scheduling does not establish
cross-thread memory correctness.

## Delivery passes

| Pass | Deliverable | Completion gate |
|---|---|---|
| **7a — Erasure and depth feasibility** | A private construction-paired erasure owner and an erased machine; a runtime-built recursive structure of one stable type; erased dispatch and allocation costs against the typed baseline; the origin result; the ordinary error-law mapping on paper. | Machines of different types run behind one carrier type with move-only values/errors and exact destruction counts at source/package O0/O3; a million-deep runtime chain is built and torn down iteratively under a 1 MiB stack; costs and the origin precondition are recorded here. No production migration. |
| **7b — `IO` and fiber API proposal** | Specify the public `IO[T, E]` surface in Cats Effect vocabulary, callback admission, the private node kinds, join ownership, failure accounting, and the migration from typed recipes, using 7a evidence. | A concrete API migration proposal reviewed before Pass 8. |
| **8a — Iterative sequencing and unwinding** | Implement `IO[T, E]` over the private node representation; drive continuations, errors, masks, finalizers, and disposal through one iterative engine registered once per fiber. Migrate the public async operations, family, examples, and guide from typed recipes to `IO`. Record an allocation baseline. | Runtime-built deep binds and recursive deferred programs satisfy the stack contract, including cancellation, failure, and unopened disposal; existing lifecycle behavior remains qualified. |
| **8b — Budgets and test stepping** | Add transition accounting, separate cancellation/yield budgets, and controllable test-host stepping on the same engine. | Budget checks cover nested work and masked cleanup. |
| **8c — Owned native callbacks in free operations** | Give the free `map`, `flat_map`, `traverse`, and other free entry points whose callbacks a deferred family retains owned overloads for plain functions, as `Pipeline` has. See the [proposal](#pass-8c-proposal). | `IO` accepts plain functions through the free operations; eager families resolve them unchanged; closures stay rejected for `IO`. |
| **9 — General lightweight fibers** | Add typed handles, start/join/cancel, completion observers, `cede`, `never`, dynamic scoped ownership, and bounded diagnostic snapshots. Generalize canonical task storage rather than wrapping the homogeneous nursery. | Heterogeneous children progress independently; joining parks; all shutdown paths drain; each failure is joined or reported exactly once; sequential spawn/join churn reuses storage; diagnostic handles do not retain payloads or completed graphs. |
| **10 — Cancellation and spawn capabilities** | Add generic error/defer/cancellation/spawn contracts and provider forwarding; expose `race_pair` with settled ownership rules and a `Supervisor` that owns fibers beyond one program's lifetime. Reuse them for existing higher-level operations where contracts match. | Generic clients use minimal capabilities across actual and test providers; law/admission checks pass; no duplicate masking, error, or child-draining policy. |
| **11 — Coordination and temporal capabilities** | Add generic Ref/Deferred access and time/sleep/timeout contracts over canonical owners. Specify unique identity and clock domains; extend controlled scheduling to event delivery and virtual time. Audit ownership-sensitive derived operations. | Reproducible manual-time and cancellation laws respecting promised event ordering; no polling loop masquerading as suspension; no async collection API additions. |
| **12 — POSIX host integration** | A POSIX polling system (`poll()` and a self-pipe) owned by each root; completion and notification safe from other threads; `run` parking until the next deadline or wake; a host notifier for embedding loops; a blocking worker pool with `blocking` and `interruptible`; a low-level file-descriptor readiness API for library authors; and wall-clock time. | Every advertised `Sync` and `Async` operation has a real provider and tests on Linux; wake before park, publication, owned and borrowed teardown, and cancellation of blocking work pass; nothing polls on a timer where it could park; remaining gaps are published with their exact obligation. |
| **13 — Multi-threaded work-stealing runtime** | A work-stealing compute pool after Cats Effect's: per-worker queues, stealing, polling and timers integrated per worker, and blocking hand-off; the payload thread-safety contract and an audit of every shared structure; the single-threaded runtime kept selectable for tests and embedding. | Fibers run in parallel with the same outcomes, laws, and ownership guarantees; the runtime's own structures are race-free under stress; throughput and latency are measured against the single-threaded runtime; `TestControl` stays deterministic. |
| **14 — Advanced preview qualification** | Publish the provider/semantic matrix, migration guidance, runnable examples, and retained evidence. Qualify controlled schedule replay and diagnostic overhead; compare lifecycle, storage, and performance with the foundation. Evaluate pooling only against the allocation baseline. | Source/package O0/O3 checks, public generic clients, ownership rejections, bounded-stack, responsiveness, replay, and storage checks pass; any pooling preserves prompt reclamation and exact destruction. Run a separately scheduled overnight qualification before making sustained-load claims. |

Pass 7a is the first implementation step. Its scope is small feasibility
experiments, not an unreviewed public API migration. Passes 8–11
form the first useful advanced-runtime milestone. Pass 12 integrates it with
POSIX hosts, and Pass 13 makes it multi-threaded; Pass 14 qualifies the result
as a preview. Neither integration pass counts as complete merely because an
operation's syntax exists.

Each implemented pass gets targeted validation, a commit and push to shared
`nightly`, and an updated status in this page. Fetch and integrate other agents'
work before pushing. Keep this as one living plan instead of creating separate
pass journals. Retire it or fold completed decisions into current architecture
documentation once the work is delivered.

## Pass 7a results

Owners: `src/fp/_internal/erased.mojo` (`_Erased`) and
`src/fp/effects/_async/erased.mojo` (`_ErasedMachine`). Clients:
`erased_storage` and `erased_depth` under `experiments/async-state-machines/tests/`.
Probes: `experiments/async-state-machines/probes/erased_cost.mojo` (timings) and
`erased_borrow.mojo` (compile only).

- **Erased storage works on Mojo 1.2.** `_Erased` reuses the allocation of a
  native `OwnedPointer`. A destroy function specialized by the stored type
  rebuilds that owner, which runs the destructor and frees the storage. Pass
  8a later added inline storage for small trivially movable values.
  `_ErasedMachine[T, E]` adds a poll function specialized by the machine type.
  Machines of three types ran behind one carrier, in a `Nursery`, and inside
  `both`. Move-only values and errors, moves, unopened disposal, and
  cancellation destroyed every payload exactly once. Origins in `T` and `E`
  remained in the carrier.
- **Lent addresses must carry the owner's origin.** A probe that copied the
  untracked address out of a local `_Erased` read freed memory: ASAP
  destruction ended the owner at its last use, before the operation ran.
  `_Erased.pointer[T]()` now lends the address only with the owner's
  origin, as the standard library's `_ErasedWriter` does.
- **Recursive frames need explicit destructors.** Mojo 1.2 accepts a field of
  type `Optional[OwnedPointer[Self]]` only when the struct declares `__deinit__`.
  A destructor that detaches descendants in a loop tore down a million-link
  chain under a 1 MiB stack. The chain was built at runtime as one type, with
  erased payloads of two types. A control whose destructor drops its child
  recursively crashed at the same depth and passed with an unlimited stack.
- **The origin precondition is unchecked.** `erased_borrow.mojo` erases a machine
  that borrows a local and returns it. It compiles with `--Werror` and no
  diagnostic; it is never executed. The same escape through the typed machine
  is rejected.
- **Erasure is not the cost.** O3 medians of nine samples, four runs on the
  session host: typed poll about 1.6 ns, erased poll 4.4–5.0 ns; allocating,
  polling, and freeing one heap frame 33–38 ns typed and 34–49 ns erased. The
  current engine's loop iteration takes 2.4–3.4 µs with typed or erased steps
  alike. Per-slot registration and wait bookkeeping, not erasure, dominate the
  current per-step cost. Pass 8a should aim for a per-bind cost near the cost of
  a heap frame, which requires registering once per fiber.

The canonical runner passed all 16 source/package O0/O3 checks for these two
clients plus the `foundation` and `nurseries` regressions, including
`erased_depth` under a 1 MiB stack on every route.

Consequences for 7b and 8a: interpreter frames are explicit node structs with
iterative destructors; every erased operation borrows through `pointer[T]()`;
programs captured inside user callbacks are still destroyed by native
destructors, which is a documented limit.

## Pass 7b proposal

Status: **reviewed on 2026-10-30**; the [review decisions](#review-decisions)
are below. The public async API follows Cats Effect. `IO[T, E]` is the one public async effect type, and how
the runtime represents or executes a program is not part of the public API.

### Public surface

End users write declarative programs with Cats Effect vocabulary: `IO`, fibers,
`Deferred`, `Resource`, races, and timeouts. Every public async operation returns
an `IO`, and a program's type never records how it was built.

| Cats Effect | FP Mojo (proposed) | Notes |
|---|---|---|
| `IO[A]` | `IO[T, E]` in `fp.effects.async_runtime` | Movable, not copyable. One value runs once; repeated work comes from a function that builds a new `IO`. `E` is the exact domain error. |
| `IO.pure`, `IO.delay`, `IO.defer`, `IO.raiseError` | `IO[T, E].pure`, `.delay`, `.defer`, `.raise_error` | `defer` makes recursive programs build lazily. |
| `IO.async`, `IO.async_` | `IO[T, E].async`, `IO[T, E].async_` | Callback registration over the existing completion owner. `async` also takes the withdrawal, which runs after every entered registration rather than only on cancellation as Cats Effect's finalizer does; `async_` has none. `async` is declared with backticks because it is a Mojo keyword, and called without them. |
| `flatMap`, `map`, `handleErrorWith`, `attempt` | `flat_map`, `map`, `handle_error_with`, `attempt` | Methods and `Pipeline` stages. `Async[E]` remains the public family; its carrier becomes `IO`, so `tail_rec_m[Async[E]]` returns an `IO`. |
| `guarantee`, `guaranteeCase`, `onCancel`, `uncancelable`, `IO.canceled` | `guarantee`, `guarantee_case`, `on_cancel`, `IO.uncancelable`, `IO.canceled` | `uncancelable` receives the existing `Poll[E]`. |
| `start`, `Fiber.join`, `Fiber.cancel` | `start`, `Fiber[T, E].join`, `.cancel`, `.request_cancel` | See the [fiber contract](#fiber-contract). |
| `IO.cede`, `IO.never`, `IO.sleep` | `IO.cede`, `IO.never`, `IO.sleep` | |
| `both`, `race`, `racePair`, `timeoutTo` | `both`, `race`, `race_pair`, `timeout_to` | `race_pair` arrives in Pass 10. Cats Effect's raising `timeout` has no counterpart without a universal error type; `timeout_to` and the existing `race_first` and `timeout_after` policies keep their names. |
| `Deferred`, `Ref`, `Queue`, `Semaphore` | the same names | Existing coordination owners; operations return `IO`. `Ref` arrives in Pass 11. |
| `Resource[IO, A]` | `Resource[T, E]` | `use` builds an `IO` from a borrowed resource that the result cannot retain. |
| `unsafeRunSync`, `IORuntime`, `ExecutionContext`, `reportFailure` | `run`, `Driver`, an `ExecutionContext` contract, a failure reporter | The context starts as the cooperative single-thread provider; see [host services](#embedding-and-host-service-ownership). |
| `Supervisor` | `Supervisor` | Pass 10. |

`Fiber` here is distinct from the existing OS-thread `fp.effects.Fiber`; the
namespaces separate them. `IO` in `fp.effects.async_runtime` is likewise distinct
from the synchronous `fp.effects.IO[E]` family; the guide already imports the
async namespace as `ar` when both are in scope. Folding the synchronous family
into the async `IO`, as Cats Effect has one `IO`, is a later decision.

Integration authors keep the `Machine` protocol in
`fp.effects.async_runtime.protocols` for custom leaves, the counterpart of
wrapping external events with `IO.async`. Lifting a machine into an `IO` is that
namespace's only addition.

### Callback admission

`IO` keeps origins only through `T` and `E`, so the callbacks stored in an `IO`
must own their state. Its entry points accept plain functions, capture-free
lambdas, and library callables that own their state. Capturing closures, and
adapters that wrap them, are rejected wherever the signature can tell. A
callable struct holding a pointer cannot be detected; it is a documented rule,
like the scoped-loan rules today. Pass 8a probes whether closures with only
owned captures can be admitted safely.

### Internal representation

The runtime representation is private. An `IO` is a flat program: one head
that the run loop evaluates first, and the continuation frames applied after it
in order. `flat_map`, `map`, and `handle_error_with` append a frame; they never
nest one program inside another.

| Head | Payload | Evaluation |
|---|---|---|
| Pure | boxed value | Deliver success. |
| Fail | boxed `EffectFailure[E]` | Deliver failure. Every program in one chain shares `E`. |
| Leaf | private machine whose value is boxed on completion | Poll through a canonical `_Slot`. |
| Defer | boxed factory | Invoke once; install the program it returns. |
| Mask | boxed factory receiving `Poll[E]` | Check cancellation, enter a masked region through `context._mask()`, and install the program the factory returns. |
| Restore | `Poll[E]` and a program | Run the program under the state preceding the poll's region (`poll(fa)` in Cats Effect). |

| Frame | Applies to | Behavior |
|---|---|---|
| Bind | success | Invoke the continuation after the handoff checkpoint; install the program it returns, or a mapped value. |
| Recover | failure whose `canceled` flag is false | Invoke the handler; install the program it returns. |
| Finalize | any outcome | Settle the outcome, then run the cleanup masked with its exact exit. `on_cancel` skips cleanup unless the exit observed cancellation. |
| Finish | the cleanup's outcome | Restore the context and merge body and cleanup errors through `_finish`, then settle. |
| Region exit | any outcome | Restore the context in effect before a mask or restore region; leaving a mask protects a success until the next checkpoint. |
| Start, join, cancel | fiber operations | Pass 9. |

Entering a program moves its head into the run loop and pushes its frames onto
one stack, so that the first continuation to apply is on top. A callback writes
the program it builds directly into the run loop through an engine-fixed
pointer.

Today's typed recipe machines (`both`, `race`, timeouts, scopes, callbacks,
coordination waits) become private leaf implementations behind the public
operations. They keep native stack depth proportional to their static type, so
the stack guarantee covers the run loop's heads and frames. Rebuilding `both`
and `race` on fibers in Pass 10 brings them under it.

Values and callbacks cross the run loop in `_Erased` boxes. A trivially movable
value of at most 24 bytes lives inline; larger values or ones with custom moves
take one allocation. A box is opened only by a function specialized at the typed
call that consumes it: `flat_map` on `IO[T, E]` specializes the continuation's
unboxing for `T`, and an `IO`'s own result is unboxed as its `T`. The typed
public API therefore pairs every cast with the type that created the box.

Frames live in `List` storage, with a program's first frame inline. Disposing of
an unopened or partially run `IO` therefore never recurses, except for values
captured inside user callbacks, which native destructors still release.

### Execution

The run loop alternates two moves until it suspends, completes, or spends its
transition budget:

1. **Evaluate** the current node. Pure and Fail produce an outcome. Bind,
   Recover, Finalize, and Mask push a frame and descend. Defer replaces the
   node. Leaf polls the active leaf slot and, if pending, returns its wait.
2. **Deliver** an outcome to the top frame. A bind continuation runs only on
   success, after the handoff checkpoint. A recovery handler runs only on a
   failure whose `canceled` flag is false. A finalizer runs masked with the exit
   case, and its outcome merges through canonical `_finish`. A mask exit
   restores the context. Other frames are dropped. An empty stack completes the
   fiber.

Cancellation, settlement, and error merging reuse their existing owners: the
`_Slot` entry checkpoint and `_settle` for leaves, `_capture` for callbacks,
`_finish` for finalizer outcomes, `context._mask()` and `Poll` for regions, and
protected success for masked completion. The interpreter adds sequencing, not
policy. Each fiber registers one wake-registry node, plus one for its active
leaf. Binds, recoveries, and finalizer frames register nothing. When the budget
runs out, the loop returns a runnable `Wait()`. Pass 8a uses a fixed budget;
Pass 8b makes it a policy.

### Fiber contract

`start` follows Cats Effect's spelling with structured ownership: the fiber that
runs `start` owns the child.

- `io.start()` is an `IO[Fiber[T, E], E]`. On entry, it admits the child into
  the running fiber. An `IO` chain shares one error type, so the child's `E` is
  the owner's `E`. A program with a different error type runs as a leaf with its
  own interpreter and owns its own children.
- `Fiber[T, E]` is move-only. `join(deinit self)` returns `IO[Outcome[T, E], E]`:
  it parks until the child and its cleanup finish, then transfers the outcome
  once. `cancel(self)` requests cancellation and waits for termination without
  taking the result. `request_cancel(self)` only requests.
- When a fiber's own program is terminal, it cancels its unjoined children and
  drains them before completing. Unlike Cats Effect, fibers never outlive their
  owner; this is the existing rule that no running work is abandoned.
- A child's success goes into a typed cell shared only by its handle and its
  task. Its failure stays in owner state typed only by `E`, so the owner can
  report an unobserved failure without knowing `T`.
- `join` moves the failure out of owner state, or the success out of the cell.
  Dropping a handle neither stops nor detaches the child; its success is
  destroyed once the child completes, and its failure is reported.
- If a joiner is canceled after taking the right but before delivery, the
  failure returns to owner state to be reported, and a suppressed success is
  destroyed once.
- An unjoined child's failure never changes its owner's outcome. As in Cats
  Effect, where `reportUnhandledFiberErrors` is on by default, it goes to the
  runtime's failure reporter, a host service beside the `ExecutionContext`. A
  move-only failure is either joined or reported, never both, so it is reported
  once it can no longer be joined: when its handle is dropped or its owner
  finishes. Cats Effect instead reports at completion when no joiner is waiting.
  The default reporter writes one diagnostic line (the error text when `E` is
  `Writable`, otherwise its type and error count) and destroys the failure.
  Hosts can replace the reporter or turn reporting off.
- Fiber storage generalizes the nursery's child slots with generation-checked reuse,
  so start/join churn does not grow storage. Fiber scheduling reuses the wake
  registry; Pass 9 decides between polling children through their owner and a
  flat runnable set at the root, preferring the flat set so that nested fibers
  cost no native stack.
- A direct self-join is a protocol violation detected at join entry. Indirect
  dependency cycles are not detected.

### Error and cancellation laws

Unless a row says otherwise, these compare programs run without a cancellation
request.

| Law | Expected | Reason |
|---|---|---|
| `raise_error(e).handle_error_with(h)` equals `h(EffectFailure([e], canceled=False))` | Holds | `raise_error` never sets `canceled`, and recovery admits only such failures. |
| `pure(a).handle_error_with(h)` equals `pure(a)` | Holds | A recovery frame is dropped on success. |
| `raise_error(e).attempt()` equals `pure(Err(...))`; `pure(a).attempt()` equals `pure(Ok(a))` | Holds | `attempt` is `map` plus recovery, as in `Async[E]` today. |
| A failure with `canceled` set bypasses recovery and `attempt` | Holds by design | It belongs to the cancellation side, and keeps finalizer errors that Cats Effect would only report. |
| `IO.uncancelable(poll => poll(fa))` equals `fa` | Expected | The mask and `Poll` restoration are the existing owners. |
| A masked success survives cancellation requested during its region | Holds | The existing protected-success rule; the next checkpoint observes cancellation. |
| Finalizers run once, innermost first, with the exact exit case | Holds | Finalize frames unwind in stack order through `_finish`. |
| Racing two canceled children under a mask | Recorded difference | Terminal cancellation, as [racing](async-racing.md) documents, rather than Cats Effect's indefinite wait. |

Pass 8a law clients check sequencing and recovery against observable outcomes and
destruction counts. Pass 10 adds the cancellation and spawn law suites.

### Migration

This replaces the preview's typed recipe surface:

- **Removed from the public API:** the recipe type aliases `Pure`, `Bind`, `Loop`,
  `Both`, `Scope`, `RaceFirst`, `Race`, `EvalIO`, `Delay`, `NativeDelay`,
  `Guarantee`, `OnCancel`, `GuaranteeCase`, `Masked`, `Uncancelable`, `Callback`,
  `Sleep`, `TimeoutAfter`, and `TimeoutTo`; the resource plan types;
  `ScopedBoth`; and `Nursery` and `Spawner`, which `start`/`join` and a later
  `Supervisor` replace. They remain as private implementations where useful.
- **Changed:** the free functions (`pure`, `delay`, `both`, `race`, `guarantee`,
  `sleep`, and the rest) return `IO`, or become `IO` methods. Function signatures
  in user code change from recipe types such as `Pure[Int, Int]` to `IO[Int, Int]`.
- **Kept:** `Async[E]` as the family, `Driver`, `run`, `Clock`, `Progress`,
  `Duration`, `Instant`, `Poll`, `Completion`, `Deferred`, `Queue`, `Semaphore`,
  and the extension protocols.

Pass 8a lands the migration in one change: reviewed `public-exports.json`,
`api.json`, and `compatibility.json` entries, migrated examples, and an
old-to-new table in the [async guide](../guides/async-runtime.md), following the
[documentation process](../contributing/documentation.md). As an opt-in preview,
the old names are removed rather than deprecated.

### Review decisions

Decided on 2026-10-30:

1. An unjoined child's failure is reported separately, as Cats Effect does, and
   never changes its owner's outcome.
2. The old recipe names are removed directly, without a deprecation release.
3. `Nursery` and `Spawner` retire in favor of `start`/`join` and a later
   `Supervisor`.
4. A direct self-join aborts as a protocol violation.
5. Names follow Cats Effect where it has established ones (`async`, `async_`,
   `timeout_to`, `race_pair`, `Supervisor`), and otherwise keep this library's
   existing names (`request_cancel`, `race_first`, `timeout_after`).

## Pass 8a progress

Steps 1 and 2 are complete: the private engine core, optimized, and
finalizers, masks, and law clients. Step 3 switches the public API to `IO` in
four parts: the `Async[E]` family (3a, complete), constructors and combinators
(3b, complete), coordination and resources (3c, complete), and the public exports and documentation
(3d, complete). The full verification gates run after step 3.

- `src/fp/effects/_async/engine.mojo` implements `IO[T, E]` as a flat program
  with pure, fail, leaf, defer, mask, and restore heads and bind, recover,
  finalize, finish, and region-exit frames. The run loop has an explicit frame
  stack and a fixed budget of 1,024 transitions per poll. It is not exported
  publicly yet.
- Finalizers and masks reuse their canonical owners: `_settle` before cleanup,
  `ExitCase` and `_ExitState` for the borrowed exit, `context._mask()` for
  masked cleanup and regions, `Poll` restoration, and `_finish` to merge errors.
  The run loop keeps the innermost region's context and reselects the effective
  context only when a region begins or ends, so binds pay no masking cost.
- A finalizer installed by a continuation that already ran is armed, as in Cats
  Effect: cancellation observed at the body's first checkpoint runs it. A typed
  `guarantee` that was never entered still skips its cleanup.
- `io_engine` covers sequencing, `map`, failures skipping later continuations,
  recovery, deferred construction, leaves resuming a chain, `IO` values inside a
  typed `both`, cancellation while a leaf runs, unopened disposal, and inline,
  boxed, and custom-move values, with exact invocation and destruction counts.
- `io_finalization` covers cleanup after success and failure, body errors before
  cleanup errors, innermost cleanup first, the exact exits a `guarantee_case`
  factory borrows, `on_cancel`, cleanup suspending masked to completion under
  cancellation, masked success, `Poll` restoration, and the region entry
  checkpoint.
- `io_laws` checks left and right identity, associativity, the raise/handle and
  pure/handle laws, recovery bypassing a failure with `canceled` set,
  `uncancelable(poll => poll(fa))` against `fa` with and without cancellation,
  and masked success. The attempt laws follow when `IO` joins the `Async[E]`
  family in step 3.
- `io_depth` runs these under a 1 MiB stack: a million-bind chain built at
  runtime, a million nested `defer` levels (a million frames), a million
  tail-recursive steps (bounded frames), disposal of an unopened million-step
  chain, a failure crossing a million frames to recovery, cancellation
  unwinding a million pending frames, and a failure crossing 100,000 nested
  finalizers.
- Mojo 1.2 crashes compiling a stored function type whose signature contains
  its owner, so callbacks receive the run loop through an engine-fixed pointer;
  see [native boundaries](native-boundaries.md#mojo-12-compatibility).

**Performance.** These are O3 medians of nine samples on the session host,
measured by `experiments/async-state-machines/probes/erased_cost.mojo`:

| Measurement | First engine | Optimized engine | Typed recipes |
|---|---:|---:|---:|
| Loop iteration through `flat_map` | 1.15 µs | 39–60 ns | 2.7–3.4 µs |
| Same loop, raising callback | — | 40–72 ns | — |
| Runtime-built `map` chain, build and run, per stage | — | 64–84 ns | — |
| Runtime-built `flat_map` chain, build and run, per stage | — | 67–82 ns | — |

The common bind allocates nothing: values and callbacks of at most 24 bytes live
inline, and a program's first frame is inline. A tail-recursive run keeps a flat
10 MB peak RSS from 100,000 to 4,000,000 steps. Callgrind counts about 200
instructions per loop step, down from about 10,900; step 2's region tracking
adds about 17.

Two Mojo 1.2 code-generation findings shaped the engine. First, `Optional` and
`Variant` values holding large structs are built and moved out of line unless
the compiler inlines them; the same first engine ran six times faster when built
with `-g`. The engine therefore keeps state as kind tags and slots, with
`MaybeUninit` where a slot may be empty. Second, building a `Result` that holds
an `IO` cost about 1,000 instructions per step whenever another instantiation
changed inlining decisions. Callbacks therefore install their program directly:
non-raising callbacks go through `_unary_once_as[Never]`, and raising ones
through a `try` that builds the canonical `EffectFailure`.

**Step 3a: `IO` joins the `Async[E]` family.** The public-ready `Async[E]` is
defined beside `IO` in `engine.mojo`, with `IO` as its carrier, so `Pipeline`,
`tail_rec_m`, `traverse`, `collect`, `product`, and `attempt` work on `IO`.

- The family overrides the private fold and loop. Each fold step binds after the
  step's `IO`, so a fold or loop of any length runs on the run loop in constant
  native stack, with one allocation for its state.
- `IO`'s methods and the family share their callback admission. It rejects
  borrowed callback views (the private `_BorrowedView` marker on the native and
  library reference adapters): erasure would drop the origin that keeps a
  borrowed callback alive.
- Mojo 1.2 closure types cannot be told apart from plain functions by type
  predicates, so rejection follows the adapter. `Pipeline` stores plain
  functions as owned callables, which are admitted, and borrows closures, which
  are rejected. Free `map`, `flat_map`, and `traverse` borrow every native
  callback, so with `IO` they take `as_unary(f)` or a library callable
  (until Pass 8c).
- `io_family` checks family selection, recovery of a native callback error,
  `product`, `attempt`, and deferred collection that stops at the first failure.
  It also runs a 100,000-step `tail_rec_m` and a 100,000-element `traverse`
  under a 1 MiB stack, about 14 ms together at O3.
- `reject_io_closure` (a capturing closure through `Pipeline`) and
  `reject_io_borrowed` (a native function through free `traverse`) check the
  rejections. Both compile when the admission check is disabled, so the check
  is what rejects them.
- The typed recipe family stays private for internal clients. It repeats the
  IO family's shape predicates until it retires.
- `family_origins` took 239 s to compile at O3 at the previous commit, against a
  240 s limit, and timed out beside other builds. Its limit is now 600 s, as for
  `family_iteration`; this step changed its compile time by about 3%.

**Step 3b: constructors and combinators.** `IO` gains the Cats Effect surface as
static constructors and methods. Each one reuses an existing owner:

- `both`, `race`, `race_first`, `timeout_to`, `timeout_after`, `sleep`,
  `IO.async`, `IO.async_`, `eval_io`, and `canceled` lift the existing typed
  leaves (`Both`, `Race`, `Timeout`, `Sleep`, `Callback`, `EvalIO`, and the
  synchronous cancellation request) through `IO.lift`, so their semantics do not
  change. A child `IO` inside one of these leaves runs its own run loop.
- `attempt` is the canonical `_Materialize` over `Async[E]`.
- `delay` is a `defer` whose factory returns `pure` of the function's result:
  two run-loop transitions and no leaf.
- `cede` and `never` are small private leaves.
- Plain-function overloads of `delay`, `defer`, `map`, `flat_map`,
  `handle_error_with`, `uncancelable`, `IO.async`, and `IO.async_` take
  `thin` function types, which capturing closures do not convert to. They only
  wrap the function in the canonical owned adapter (`NativeUnary` or
  `_NativeThunk`) and delegate. Register-passable results take the existing
  `_NativeOwnedArg` evidence, as `Pipeline` does.
- `io_operations` covers deferred and single evaluation, native and raising
  callbacks, `attempt`, `both`, both race policies, both timeouts, `sleep`,
  `cede` yielding once, `never` completing only by cancellation, `canceled`
  with and without a mask, `IO.async` with its withdrawal, `IO.async_`, and
  `eval_io`.

**Step 3c: coordination and resources.**

- `Deferred`, `Queue`, and `Semaphore` operations return `IO`, lifting their
  existing leaves. `with_permit` takes an `IO`, or any machine that owns its
  state, and keeps the permit in the canonical `Scope` until the body and its
  release finish.
- `Resource[T, E]` erases a typed acquisition plan once, at construction. `use`
  erases its scoped body to one carrier per resource type, runs the plan's
  `Scope` as an `IO` leaf, and unboxes the body's value with the type that
  boxed it. Leaves and scoped bodies share one step-boxing helper.
- Composition reuses the typed plan owners. `flat_map` joins the resource as the
  left plan of the canonical `_Join`, `map` reuses `_MapScopeFactory`, and
  `pure` uses the pure resource factory. `make` and the typed `resource`
  constructor share one private plan builder: the constructor's admission
  cannot be proven from a generic caller.
- Five more adapters that hold a borrowed pointer now carry the borrowed-view
  marker: the `Kleisli` view, the shared thunk reference, `MutableRef`, and the
  two binding thunks. Without it, `traverse` borrowed a `Kleisli` chain into a
  deferred `IO`; `reject_io_kleisli_view` compiles without the marker and is
  rejected with it. A `Kleisli` chain can only be called repeatedly through
  its view, so traversal into `IO` takes an owned repeatable callable instead.
- A plain-function `delay` now infers its result type, as the earlier `delay`
  did. A stored thin function pointer cannot convert to a signature spelled
  with `T`, because Mojo 1.2 does not convert between function types.
- `io_resources` covers a waiting `Deferred` read, a `Queue` take waiting for an
  offer, `with_permit` releasing its permit, acquire/use/release order,
  dependent release before its parent, release after a failed body, release
  errors after body errors, projection, and a pure resource. Internal clients
  that named the removed coordination machine types use `IO`.
- `async_coordination`, `coordination_origins`, and `coordination_owned` exceeded
  the default 120 s compile limit with four builds in parallel. Their limit is
  now 600 s.

**Step 3d: the public switch-over.** `fp.effects.async_runtime` now exports
`IO`, `Async`, `Resource`, `Deferred`, `Queue`, `Semaphore`, `Clock`, `Driver`,
`run`, `Progress`, `Duration`, `Instant`, `RaceResult`, `Poll`, and
`Completion`.

- The recipe aliases and free functions, the typed resource plans, `Nursery`,
  `Spawner`, and `ScopedBoth` are no longer public. They remain private
  implementations where `IO` lifts them.
- `protocols.Machine` is now the kernel machine contract, with no `Family`
  requirement, because `IO.lift` runs any machine. `Driver` and `run` accept
  it too. Existing machines that declare `Family` still conform.
- `IO`'s constructor is private and keyword-only, since it takes the engine's
  program.
- The six examples print their reviewed output unchanged. The public clients,
  the guide (with an old-to-new table), the README, the reference index,
  `public-exports.json`, `api.json`, and `compatibility.json` are migrated.
  The two export contracts also take `MutableRef`'s marker from step 3c.
- `public_owned` now checks owned callable state where it previously checked
  closures with moved captures. `IO` rejects capturing closures, which
  `public_reject_capture` checks.
- `public_traversal_view` traverses with an owned repeatable callable. A
  deferred `IO` cannot keep a borrowed `Kleisli` view.

**Review follow-up: scoped resources.** `ScopedMachine` and `CleanupMachine`
stay public, with `Resource` operations that take them:

- `use_scoped` polls a `ScopedMachine` body with a fresh loan on every poll, so
  work that suspends can keep using a move-only resource.
- `make_case` takes a `CleanupMachine` release that sees the exact exit, like
  Cats Effect's `Resource.makeCase`.
- Both reuse the canonical plan and `Scope` owners. `public_resource_scoped`
  covers loans across a suspension, and release after success, failure, and
  cancellation.

**Review follow-up: the typed recipe family is retired.** `IO` is the only
carrier of the `Async[E]` family, so the family's admission rules have one
implementation.

- Removed: the typed `Async` family and its recipe wrapper, the typed
  application names, and the typed recovery functions. The typed resource
  wrapper and its constructors are also removed, since `Resource` erases the
  same plans.
- The private typed machines that `IO` lifts (`Both`, `Race`, `Timeout`,
  `Sleep`, `Callback`, `EvalIO`, `Scope`, coordination and finalization leaves)
  stay as its internal leaves. They implement the plain `Machine` contract,
  without family metadata, and `IO` declares its family directly.
- The pure resource factory moved beside `Resource`, which now owns the plan
  entry points.
- Internal clients that tested the typed surface were ported to `IO`, or removed
  where an `IO` client already covers the same behavior. Removed:
  `family_iteration` (covered by `io_family`); `application_aliases`,
  `application_native`, and `application_owned` (covered by the public and
  `io_*` clients); the two application rejection fixtures and two internal
  resource rejection fixtures (covered by public fixtures); and
  `resource_generic` (covered by `public_resources` and
  `public_resource_scoped`). `application_errors` became `io_native_errors`.
- `async_recovery` checked that the typed bind yielded once before entering a
  handler. `IO` runs a handler in the same step, so the client now checks the
  semantic that yield protected: a failure observed with cancellation requested
  keeps its errors and bypasses recovery.
- `instant_cleanup` and `instant_timers` still exercise the private leaves
  directly.
- `IO[NoneType, E].delay` also takes a plain function with no return value,
  raising or not. The shared delay adapter maps the missing result to
  `NoneType`, and the examples' cleanup functions no longer spell it out.

## Pass 8b proposal

Status: **complete** ([progress](#pass-8b-progress)). Pass 8b finishes Pass 8: transitions become the
unit of work, yield and cancellation checks become separate policies, and tests
can step the same engine one transition at a time.

### Current state

- Each `IO` run loop yields after a fixed 1,024 transitions per poll. An `IO`
  inside a leaf, such as a child of `both`, has its own run loop and its own
  1,024, so one root poll's work grows with nesting depth.
- `Driver.poll(budget)` counts root polls and timer events, not transitions.
- Cancellation is observed at every bind and recovery handoff, at leaf entry,
  and at region entry.
- Manual clocks, `Driver.poll` budgets, and `Progress` already drive programs
  deterministically, one root poll at a time.

### Proposal

1. **One transition budget per root poll.** The root task refills a slice at
   each root poll. Every run loop in that task tree draws from the same slice
   through its inherited context, and yields with a runnable wait when the slice
   is spent.
   - Counted transitions: evaluating a head; applying a bind, map, or recovery;
     unwinding a finalize, finish, or region-exit frame; and polling a leaf.
   - Native callback bodies, custom polls, and destructors stay uncounted and
     cannot be preempted; the guide states that boundary.
   - The counter is private, carried in the context beside the clock and
     scheduler, and thread-confined. A run loop reads it once per poll and
     writes it back on return, so the hot loop does not change.
2. **Separate yield and cancellation policies**, as in Cats Effect's
   [`IORuntimeConfig`](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/unsafe/IORuntimeConfig.scala):
   - `auto_yield_threshold`: transitions per root poll; default 1,024.
   - `cancelation_check_threshold`: binds between handoff checks; default 1,
     which is today's behavior.
   - Validation: both must be positive, and the yield threshold a multiple of
     the check threshold, so every yield point is also a check point and
     yielding cannot disable checks.
   - Leaves, region entries, and masked cleanup keep their own checkpoints.
     Masked cleanup may yield without becoming cancelable, because the region's
     context is run-loop state.
3. **Host configuration.**
   - `Driver(program, token, clock, config)` and `run(program, config)` take the
     configuration; the existing constructors keep the defaults.
   - `Progress` gains `transitions`, the transitions spent in the call.
4. **Test stepping on the same engine.**
   - With `auto_yield_threshold = 1`, `Driver.poll(1)` runs exactly one
     transition.
   - `Progress` gains `quiescent`: not completed, nothing runnable, and no live
     deadline, so the program awaits external input. A test host treats
     quiescence as deadlock only when it knows no input will arrive.
   - Virtual time remains `Clock.manual` with `advance_to(progress.deadline)`.
     Event and choice traces arrive with fibers, whose start, join, and cancel
     races need them.
5. **Measurements.** Transitions per root poll for nested `both` trees and long
   chains; wall-clock per root poll at the defaults; and the IO loop probe with
   cancellation intervals of 1 and 512.

### Gate and clients

- `io_budget`:
  - A million-bind chain takes the expected number of root polls.
  - A nested `both` of long chains never exceeds the threshold plus one
    transition per leaf poll in a root poll.
  - Masked cleanup running a long chain yields between polls and completes
    without observing cancellation.
  - With a check interval of k, cancellation is observed within k binds.
  - Invalid configurations raise setup `Error` at construction.
- `io_stepping`: single-steps a small program and checks each transition's
  effect, quiescence against completion, and manual time.

### Review decisions

Decided on 2026-10-30:

1. The configuration is `IORuntimeConfig`, as in Cats Effect.
2. The default check interval is 1, every bind. The IO loop probe measures its
   cost at 1 and 512; if the cost is not negligible, the default becomes Cats
   Effect's 512.
3. `Progress` gains `transitions` and `quiescent`.
4. Pass 8c runs in a parallel session, in its own container, while Pass 8b is
   built; Pass 9 follows Pass 8b.

### Pass 8b progress

Built on 2026-10-30 as approved, with one addition: `run` also takes a token
and a configuration together.

- **Budget.** The private `_Budget` in `_io_core.mojo` holds the remaining and
  consumed transitions and both thresholds. `IOContext` carries it through
  `copy`, `_inherit`, and `_restore`, so children, scopes, and masked regions
  share their root's budget. `Task._poll_ready` refills it before each root
  poll. A context without a root budget, such as one a test polls directly,
  falls back to the run loop's own 1,024.
- **Run loop.** `_RunLoop.run` reads the remaining budget once, counts
  transitions in a local, and calls `_publish` before polling a leaf and before
  returning; it reloads the budget after the leaf. Handoffs decrement a check
  countdown and observe cancellation when it reaches zero.
- **Leaf polls.** A leaf poll first spent its own transition, so at a threshold
  of one, or with leaf nesting as deep as the threshold, a nested `IO` such as a
  `both` child always found the budget spent and never progressed. The leaf
  poll now publishes its transition to the run loops inside it and counts only
  when they spent nothing. `io_stepping` steps a nested `both` at a threshold of
  one, and `io_budget` checks that two children share root polls at a
  threshold of two.
- **Host.** `IORuntimeConfig` lives in `kernel.mojo` and validates as Cats
  Effect does. `Driver(program, token, clock, config)`, `run(program, config)`,
  and `run(program, token, config)` take it; existing constructors keep the
  defaults. `Progress` gains `transitions` and `quiescent`.
- **Clients.** `io_budget` runs a 100,000-bind chain at a threshold of 1,024,
  a `both` of two 5,000-bind chains at 64, masked cleanup of a 5,000-bind chain
  under cancellation at 64, check intervals of 1 and 8, and invalid
  configurations. No root poll exceeds the threshold; children and masked
  cleanup yield between root polls. It also runs under a 1 MiB native stack.
  `io_stepping` steps a head and three frames, then a nested `both`, one
  transition per poll through the public `Driver`. It checks quiescence on a
  parked `Deferred.get` and its cancellation, completes a sleep under manual
  time, and runs both configured `run` overloads.
- **Measurements.** In the `erased_cost` probe at O3, an `IO` loop iteration
  costs 39.1 ns without handoff checks and 39.3 ns with a check at every bind.
  With the shared budget and countdown in place it costs 38 to 41 ns, within
  run-to-run noise of the 39 to 60 ns recorded in Pass 8a. The cost is
  negligible, so the default check interval stays 1. At the defaults, a root
  poll of a plain bind loop runs 1,024 transitions in about 41 µs.

## Pass 8c proposal

Status: **built**; see [Pass 8c progress](#pass-8c-progress). The free
operations take plain functions for `IO`.

### Problem

- The free `map`, `flat_map`, and `traverse` borrow native functions and closures
  through reference adapters. Eager families call the callback before returning,
  so borrowing is safe for them.
- A deferred `IO` must own its callback, so the `IO` family rejects those
  borrows. Users must write `as_unary(f)` today.
- `Pipeline`, `tail_rec_m`, and iterator `traverse` already store plain functions
  as owned callables and borrow only closures.

### Proposal

- Give the free operations the same owned overloads for plain (`thin`) functions.
  They store an owned `NativeUnary` with the register-passable evidence
  `Pipeline` uses. Closures keep their borrowed overloads, which `IO` still
  rejects.
- Generate the overloads with the existing native-convention generator, so
  every entry point shares one adapter.
- Candidates: `fp.algebra` `map`, `flat_map`, and `traverse`, the free
  `fp.iteration` traversal entry points, and other free operations whose
  callbacks a deferred family retains. An audit lists them before building.
- Probe first:
  - Inferring the element type from the value argument when the function type
    depends on it. Each free function takes the function first and infers from
    the value, while `Pipeline` already knows the element type.
  - That eager families still resolve plain functions without ambiguity or a
    change in behavior.

### Gate

- Existing algebra, iteration, and `Pipeline` clients pass unchanged.
- `io_family` uses the free `map`, `flat_map`, and `traverse` with plain
  functions.
- `reject_io_borrowed` passes a capturing closure, which stays rejected.

### Pass 8c progress

**Audit.** Free entry points that borrow native callbacks and take a family
parameter (`filter` and `filter_not` need `Filterable`, which `IO` is not). Each
accepted `IO` with an owned library callable before this pass:

| Entry point | Callback shape | Pass 8c |
|---|---|---|
| `fp.algebra` `map`, `flat_map`, `traverse` | Owned unary | Plain functions owned |
| `fp.iteration` `traverse`, `traverse_void` | Owned unary | Plain functions owned |
| `fp.iteration` `flat_traverse`, `find_map_effect`, `fold_map_effect` | Owned unary | Plain functions owned (follow-up) |
| `fp.iteration` `traverse_filter` | Owned unary | Plain functions owned (second follow-up) |
| `fp.iteration` `fold_effect` | Binary | Plain functions owned (second follow-up) |
| `fp.iteration` `traverse_tap`, `filter_effect`, `any_effect`, `all_effect`, `find_effect` | Borrowing | Plain functions owned (second follow-up) |
| `fp.algebra` `if_effect` | Two thunks | Plain functions owned (second follow-up) |
| `fp.algebra` `tail_rec_m` | Owned unary | Already owned |

The first build covered the rows the approved gate names, and
`traverse_void`, which `Iter` already gave the same owned overloads. A
follow-up added `flat_traverse`, `find_map_effect`, and `fold_map_effect`
through a `thin` kind in `generate_traversal_syntax.py` and
`generate_effect_syntax.py`: eight by-value overloads per entry point from the
shared factory signatures, calling the same execution entry as the borrowed
and library overloads. Free `traverse_void` moved to that kind. A second
follow-up enabled the kind for the remaining rows, with the shared borrowing
(`_NativeBorrow`), binary (`_NativeBinary`), and thunk (`_NativeThunk`) factory
signatures. `if_effect` combines thin factories with each other and with library
thunks (24 overloads); a plain function beside a closure keeps the borrowed
pair, which `IO` rejects because of the closure. Every free entry point that
can return an `IO` now takes plain functions.

Follow-up probes on simplifying callback admission, including value-first free functions, are recorded in [native boundaries](native-boundaries.md#callback-admission-simplification-probes).

**Probe.**

- The `Pipeline` spelling, `def(var _NativeOwnedArg[I.Element[V]]) thin -> R`,
  does not resolve for free functions: the function comes first, so `V` is
  unresolved when the function argument is converted.
- The `as_unary` factory spelling works: a fresh `A` inferred from the
  function, `where I.Element[V] == A`, with the factory's by-value ABI
  variants (register and memory argument and result, pure and raising, no
  borrowed fallback and no no-value signatures, as on `Iter`).
- Optional, Result, and List calls select the owned overloads for plain
  functions without ambiguity and with the same results. Capturing closures
  still select the borrowed overloads.
- Naming the error as `MapContract[I, V, NativeUnary[...]].Error` does not
  reduce in a raises clause for a raising function. The overloads name it
  through `_ErrorProbe`, as the borrowed overloads do.

**Built.**

- `generate_native_conventions.py` emits the 24 `fp.algebra` overloads into a
  generated block of `operations.mojo`. Each copies the pointer into a
  `NativeUnary` and calls the shared `_map_as`, `_flat_map_as`, or
  `_traverse_as` entry, as the borrowed overloads do.
- `generate_traversal_syntax.py`'s pointer overloads for `Iter` now also emit
  the free `fp.iteration` `traverse` and `traverse_void` overloads, which
  delegate to the library-callable overloads.
- Plain functions passed to the free operations are now copied, not borrowed.
  Eager results are unchanged. For deferred Reader and State results the
  callback type is now `NativeUnary` and no longer carries the call-site
  origin. Generic code that names `X=` still selects the borrowed overloads.
- `io_family` calls the free `map`, `flat_map`, and `traverse` with plain
  functions, including a raising one. `reject_io_borrowed` passes a capturing
  closure to the free `traverse`, which is still rejected.
- Targeted runs: 51 runtime tests and examples that pass native callbacks to
  these operations, 128 compile-fail fixtures that import them, the generator
  tooling test, and the `io_family`, `reject_io_borrowed`, `family_sequence`,
  `reject_family_error`, and `reject_family_origin` qualifications (20/20).
  The full suite and gates were not run.
- Follow-up runs: 54 runtime tests and examples and 111 compile-fail fixtures
  that use `traverse_void`, `flat_traverse`, `find_map_effect`, or
  `fold_map_effect`, the generator tooling test, and the `io_family` (now also
  calling the three new entry points with plain functions) and
  `family_sequence` qualifications (8/8).
- Second follow-up runs: 71 runtime tests and examples and 208 compile-fail
  fixtures that use the newly covered entry points, the generator tooling test,
  and the `io_family` (now calling every newly covered entry point with plain
  functions), `reject_io_borrowed`, and `family_sequence` qualifications
  (12/12).

## Pass 9 proposal

Status: **complete** ([progress](#pass-9-progress)). It implements
the approved [fiber contract](#fiber-contract) on the Pass 8 engine.

### Public surface

| Cats Effect | FP Mojo | Notes |
|---|---|---|
| `fa.start` | `io.start()` returning `IO[Fiber[T, E], E]` | The fiber running `start` owns the child. |
| `fiber.join` | `fiber^.join()` returning `IO[Outcome[T, E], E]` | Consumes the handle; parks until the child and its cleanup finish. |
| `fiber.cancel` | `fiber.cancel()` returning `IO[NoneType, E]` | Requests cancellation and waits for termination without taking the result. |
| `joinWith`, `joinWithNever`, `joinWithUnit` | `join_with(fallback)`, `join_with_never()`, `join_with_unit()` | Join, replacing a cancellation-only outcome with the fallback, `IO.never`, or unit. |
| — | `fiber.request_cancel()` returning `IO[NoneType, E]` | Requests only. |
| `reportUnhandledFiberErrors`, `reportFailure` | `IORuntimeConfig.report_unhandled_fiber_errors` and a replaceable reporter | Reporting is on by default. |
| `IO.cede`, `IO.never` | Already present | |

`Fiber` lives in `fp.effects.async_runtime`, apart from the OS-thread
`fp.effects.Fiber`.

### Representation

- **Shared state.** A handle and its child share a private fiber record:
  status, the child's cancellation token, a completion signal, the failure
  (typed only by `E`), and flags for joined and dropped handles. A typed success
  cell is shared only by the handle and the child's completion step. The owner
  holds the erased child program and the record, never `T`, so it can drain and
  report without knowing `T`.
- **Flat scheduling.** The entered root `IO` hosts every fiber started beneath
  it. Fibers register as siblings in the existing wake registry, so nested
  fibers cost no native stack, and each takes its slice of the Pass 8b budget.
  An `IO` inside a lifted leaf is its own root and hosts its own fibers.
- **Start.** A new head admits the erased child into the host's generation-checked
  slot table, records its owner, and returns the handle. Slot reuse generalizes
  the nursery's child slots and the registry's generations, so start/join churn
  does not grow storage.
- **Join.** A join leaf waits on the child's completion signal, then moves the
  failure out of the record or the success out of the cell. If the joiner is
  canceled after taking the right to deliver but before delivery, the failure
  returns to the record to be reported, and a suppressed success is destroyed
  once.
- **Owner draining.** When a fiber's own program is terminal, it requests
  cancellation of its unjoined live children, parks until they finish, and only
  then completes. Fibers never outlive their owner.
- **Reporting.** A failure is reported once it can no longer be joined: when its
  handle is dropped, or when its owner finishes. The reporter is a host callback
  taking a formatted line: the error text when `E` is `Writable`, otherwise its
  type and error count. The default writes one line to standard error. A
  non-generic callback avoids the existentials Mojo 1.2 lacks.
- **Self-join.** The join leaf compares the current fiber's identity, carried in
  the context, with the handle's, and aborts on a direct self-join.
- **Diagnostics.** A bounded driver snapshot lists live fibers with an internal
  index, status, and owner, without payloads or completed graphs. `Fiber` has no
  public identity.

### Steps

1. **9a:** the host, `start`, `join`, `cancel`, and `request_cancel`, with owner
   draining.
2. **9b:** failure accounting and the reporter, dropped handles, the joiner
   cancellation race, self-join detection, and storage reuse.
3. **9c:** diagnostics; then retire the private `Nursery` and `Spawner` and move
   their internal clients to fibers.

### Gate and clients

From the delivery table:

- Heterogeneous children progress independently, and joining parks.
- Every shutdown path drains.
- Each failure is joined or reported exactly once.
- Sequential start/join churn reuses storage.
- Diagnostic handles retain no payloads or completed graphs.

Planned clients:

- `fiber_basics`: independent progress, a parking join, and cancel waiting for
  cleanup.
- `fiber_drain`: owner completion with unjoined, failed, and masked children.
- `fiber_reporting`: each failure exactly once, across dropped handles, owner
  exit, and the joiner race.
- `fiber_churn`: a million start/join cycles in constant storage under a 1 MiB
  stack.
- Rejections: joining a moved handle, and an `E` mismatch.

### Review decisions

Decided on 2026-10-30:

1. The reporter is a host callback taking a formatted line, set through the
   runtime configuration.
2. Cats Effect's `joinWith`, `joinWithNever`, and `joinWithUnit` arrive in
   Pass 9 as `join_with(fallback)`, `join_with_never()`, and
   `join_with_unit()`.
3. As in Cats Effect, `Fiber` has no public identity. Cats Effect identifies
   fibers only for diagnostics, through `IOFiber`'s string form and the
   runtime's fiber dump. Here the driver's snapshot is that diagnostic view.

### Pass 9 progress

**9a** was built on 2026-10-30: `io.start()`, `Fiber[T, E]` with `join`,
`join_with`, `join_with_never`, `join_with_unit`, `cancel`, and
`request_cancel`, and owner draining. Records, inboxes, host tables, and the
join and cancel leaves live in `src/fp/effects/_async/fibers.mojo`, below the
engine; `Fiber`, `start`, and the hosting step live in `engine.mojo`, keeping
module imports acyclic.

- **Start.** `start` is a deferred head, so it observes cancellation as `defer`
  does. Its callback reserves a slot in its host's inbox, builds the child's
  run loop with that fiber id, queues it with a new shared record, and produces
  the handle. The run loop that runs the first start
  creates the inbox and the fiber table; its `IO` hosts every fiber started
  beneath it. Each fiber's run loop carries the host's inbox and its own id, so
  a fiber's starts reach the same flat table, owned by the starting fiber.
- **Representation.** The record holds the child's token, a completion signal,
  and the settled `Outcome[_Erased, E]`. A success stays erased until `join`
  takes it as `T`, so the host never names `T` and a dropped success is
  destroyed through its erased owner. This replaces the separate typed success
  cell of the proposal with the same guarantees.
- **Scheduling.** A host `IO` runs its own program inline. Each fiber is a
  canonical execution slot polling its own run loop, registered under the
  host's wake node with tag `i + 1`; the program's leaves keep tag 0.
  `next_child` gained a tag to pass over, so fibers queued behind the program's
  leaf still run. Each poll alternates whether fibers or the program run first,
  and fibers run while the root budget lasts, once each at most, so a busy
  program cannot starve its fibers. A leaf that is not ready is no longer
  polled or counted as a transition.
- **Draining.** When a fiber's program is terminal, it cancels its live
  children and holds its outcome until they complete. Completion publishes the
  outcome, notifies the signal, and releases an owner that was only waiting;
  the cascade is iterative. The host completes once its program is terminal
  and its direct children have completed. A child canceled before its first
  poll runs nothing, through the canonical slot entry checkpoint. Completed
  slots return to a free list for reuse.
- **Handles.** `join` parks on the signal and is interruptible. `cancel`
  requests cancellation and waits uninterruptibly, as Cats Effect's `cancel`
  does. `join_with` embeds the outcome as Cats Effect's `Outcome.embed` does,
  clearing the child's cancellation flag on re-raised errors.
- **Clients.** `fiber_basics` covers interleaved progress at a small yield
  threshold, a join parked on a value another fiber delivers, `cancel` waiting
  for suspending cleanup, the `join_with` family, and nested starts.
  `fiber_drain` covers unjoined running and failed children, a masked child
  finishing its region, a fiber draining its own children before its join
  returns, root cancellation while joining, and a `both` child hosting its own
  fibers. `public_reject_fiber_moved` and `public_reject_fiber_error` reject a
  join of a moved handle and a child with another error type.
- **Measurements.** The `erased_cost` probe at O3 still runs an `IO` loop
  iteration in 35 to 39 ns.

**9b** was built on 2026-10-30: failure reporting, dropped handles, the joiner
cancellation race, self-join detection, and the churn client. One decision was
refined in review: a failure is reported when its last claim is dropped, not
also when its owner finishes. A Mojo handle is a value that can outlive its
owner and be joined later; owner completion still drops the handles its
program holds, so the usual case reports at owner completion.

- **Claims.** A `_Claim` is the single right to an outcome. The handle holds
  it, `join` moves it into the join leaf, and the leaf moves it with the taken
  outcome into a `_Delivery`. Dropping a claim releases the record: a failure
  is reported, at once or when the child completes, and a success is
  destroyed. Completion settles a released record, so each failure is joined
  or reported exactly once.
- **Joiner race.** `join` is the join leaf followed by its own map frame,
  which takes the outcome out of the delivery. A canceled joiner's leaf takes
  nothing. If a handoff observes cancellation between the leaf and that frame,
  dropping the delivery returns the outcome to the record and its claim
  reports it.
- **Reporting.** `IORuntimeConfig` gains `report_unhandled_fiber_errors`, on
  by default, and `reporter`, a `def(String) thin` host function writing to
  standard error by default. The root budget carries both, and admission
  copies them into each record. The line lists the errors when `E` is
  `Writable`, otherwise their count and type name.
- **Self-join.** `IOContext` carries the running fiber's identity, its record
  address, through copies, masks and inheritance; fiber slots restore it after
  each re-attachment. The join leaf aborts on a direct self-join. An abort
  cannot be qualified in-process, so no client exercises it.
- **Clients.** `fiber_reporting` reports through a standard-output reporter for
  a handle dropped after and before the failure, a canceled joiner, and a
  dropped delivery, and checks that a joined failure, a dropped success
  (destroyed once), disabled reporting, and a non-`Writable` error type behave
  as documented. `fiber_churn` runs a million sequential start/join cycles in
  one fiber slot and at most four wake registrations, also under a 1 MiB
  stack. A cycle costs about 7.3 µs at O3, including the driver's polls.

**9c** was built on 2026-10-30: the driver snapshot, and the private nursery
retired. Decided in review: delete the nursery-only clients, port the general
ones, rewrite the stress harness, and add `Driver.fibers()` for the root `IO`.

- **Snapshot.** `Driver.fibers()` returns a `FiberInfo` per live fiber of the
  root `IO`: its slot, its owner's slot, and a `FiberStatus` of runnable,
  suspended, or draining. `IO` implements a private `_FiberHost` trait that the
  driver downcasts to; other roots list nothing. Fibers hosted inside a leaf
  are not reachable from the driver and are not listed. `fiber_snapshot`
  covers owners, each status, completion, and a nested host.
- **Nursery.** `nurseries.mojo`, its host wrapper, and its forwarding module
  are gone, with the nursery-only clients `nurseries`, `nursery_origins`,
  `reject_nursery_escape`, `reject_spawner_escape`, and `reject_spawn_type`.
  `scheduler`, `async_coordination`, `erased_storage`, and `workload` run their
  dynamic children as fibers with the same assertions; `workload` joins its
  workers with `join_with`, so a worker's cleanup error still fails the
  pipeline. `host_admission` drops its nursery limit checks.
- **Stress harness.** The stress clients used the retired typed recipes and
  nursery. `lifecycle` now loops with `tail_rec_m` over `IO.async` with a
  timeout; `workers` composes queue and semaphore operations with `IO`
  methods; `performance` times an `IO` loop and parks sleeping fibers. Their
  output lines are unchanged, so `stress_contract.py` parses them as before.
  The recorded overnight results predate this rewrite.
- **Docs.** The nursery architecture page is replaced by
  [async fibers](async-fibers.md).

## Pass 10 proposal

Status: **approved, in progress** ([review decisions](#pass-10-review-decisions)).
Pass 10 lets generic code ask for exactly the
effect capabilities it uses, as Cats Effect's `MonadCancel` and `GenSpawn` do,
and adds `race_pair` and `Supervisor`.

### Current state

- `Async[E]` is a `Monad` and an `ErrorRecovery`, so generic code reaches
  `tail_rec_m`, traversals, and `attempt`. Everything else, `defer`,
  `raise_error`, masks, finalizers, `start`, races, and timers, is a concrete
  `IO` method that generic code cannot name.
- `Async[E]` cannot be an `ApplicativeError`. Its `Failure` is
  `EffectFailure[E]`, which can carry cancellation, and its recovery skips such
  failures, so `fail` could not satisfy the raise/handle law for every value.
  The synchronous `IO[E]` reaches `ApplicativeError` through `ResultT`, which
  does not distinguish failures marked canceled.
- The synchronous family has free `guarantee`, `on_cancel`, `guarantee_case`,
  `uncancelable_with`, and `canceled`, with its own `Poll`. The async family has
  the same operations as `IO` methods, with another `Poll`.
- Capability traits already follow one pattern: traits such as `Ask` and
  `Stateful` in `fp.effects.protocols`, generic entry points such as `ask[I]()`
  and `modify[I](f)` and transformer selections such as `LiftAsk[I, C]` in
  `fp.effects.capabilities`. Pass 10 follows it.

### Proposal

1. **Capability traits** in `fp.effects.protocols`, each a family dictionary
   that forwards to the existing owner, never a second engine. The names avoid
   the concrete `Async`, `Clock`, and `Poll`.
   - `Defer`: `defer(factory)` and `delay(function)`.
   - `Raise`: ordinary failure construction. Its raised value is the domain
     error `E`, and its law relates it to recovery:
     `raise(e).or_else(h)` equals `h(EffectFailure([e], canceled=False))`.
     `ApplicativeError` keeps its meaning for families whose failure carries no
     cancellation.
   - `Cancel` (Cats Effect's `MonadCancel`): `canceled`, `uncancelable` with the
     family's own `Poll` type, `on_cancel`, `guarantee`, and `guarantee_case`.
   - `Spawn` (`GenSpawn`), extending `Cancel`: `start` with the family's `Fiber`
     type, `never`, `cede`, and `race_pair`. Cats Effect's `Unique` stays out,
     as the Pass 9 decision on fiber identity requires.
2. **Providers.** `Async[E]` implements all four. The synchronous `IO[E]`
   implements `Defer`, `Raise`, and `Cancel` and not `Spawn`; a generic client
   needing `Spawn` is rejected at its constraint. Qualification adds a minimal
   test family with only `Defer` and `Raise`, so the rejections of narrower
   providers are checked, not assumed.
3. **Generic entry points** in `fp.effects.capabilities`, such as
   `start[I](program)` and `guarantee_case[I](program, finalizer)`, delegating
   to the provider. The existing synchronous free functions keep their
   signatures and become that provider's implementation; one implementation
   per operation.
4. **`race_pair`.** `IO.race_pair(left, right)` starts both as fibers of the
   running fiber and completes when the first finishes, producing that side's
   `Outcome` and the other side's `Fiber`. The winner's claim is consumed with
   its outcome; the loser's claim moves into the returned handle, which is
   joined, canceled, or drained by its owner like any child. If the caller is
   canceled while waiting, both are canceled and drained before `race_pair`
   completes, as in Cats Effect.
5. **`Supervisor`.** `Supervisor[E].resource(await_on_release)` is a
   `Resource[Supervisor[E], E]`; `supervisor.supervise(io)` starts `io` as a
   fiber owned by the supervisor instead of the running fiber, so it can outlive
   the program that started it. Releasing the resource cancels the supervised
   fibers that are still live, or waits for them, and drains them before
   release completes. A supervisor is an owner in the fiber table of the host
   that acquired it.
6. **Forwarding.** `LiftDefer`, `LiftRaise`, `LiftCancel`, and `LiftSpawn`
   selections forward through the transformer layers whose contracts allow it.
   An audit first records, per layer, which capabilities forward lawfully;
   finalizers through `OptionalT` and `ResultT` must observe the layer's own
   failure, as Cats Effect's transformer instances do.

### Steps

1. **10a:** `Defer`, `Raise`, `Cancel`, and `Spawn`, both providers, the
   generic entry points, and the law suites.
2. **10b:** `race_pair` and its reuse decision below.
3. **10c:** `Supervisor`.
4. **10d:** the forwarding audit and the selections it admits.

### Gate and clients

From the delivery table: generic clients use minimal capabilities across actual
and test providers; law and admission checks pass; no duplicate masking, error,
or child-draining policy.

- `capability_cancel`: one generic program over `Cancel`, run on the
  synchronous and async providers with identical outcomes and finalizer order.
- `capability_spawn`: generic `start`, `join`, and `race_pair` on `Async[E]`.
- `cancel_laws` and `spawn_laws`: the Cats Effect `MonadCancel` and `GenSpawn`
  laws that hold, plus the recorded differences: finalizer errors kept in the
  outcome, owner draining, and masked races.
- `race_pair` and `supervisor` clients: settled ownership, caller
  cancellation, release with and without waiting, and exactly-once reporting.
- Rejections: `Spawn` on the synchronous provider and on the test family, and
  `Raise` given a value of another error type.

### Review questions

1. **Raise.** A separate `Raise` capability over `E`, as proposed, or a
   documented narrowing of `ApplicativeError` whose `fail` only accepts
   uncanceled failures?
2. **One child policy.** `both`, `race`, and `race_first` run as leaf child
   groups with their own draining, while `race_pair` and `Supervisor` use
   fibers. Express the pair operations through fibers, as Cats Effect derives
   them from `racePair`, so one owner drains children? Recommendation: measure
   a fiber-based `both` against the leaf first and decide on the cost.
3. **Supervisor release.** Cancel live fibers by default, as Cats Effect does,
   or wait for them? (The supervisor became a scoped combinator in 10c.)
4. **Naming.** Generic entry points need explicit families, such as
   `guarantee_case[I](...)`, beside the synchronous free functions of the same
   name. Keep those names, or prefix the generic ones?

### Pass 10 review decisions

Decided on 2026-10-30:

1. `Raise` is a separate capability over the domain error `E`;
   `ApplicativeError` is unchanged.
2. Before 10b decides whether `both`, `race`, and `race_first` move onto
   fibers, a probe measures a fiber-based `both` against the leaf.
3. Releasing a `Supervisor` cancels its live fibers by default, as in Cats
   Effect; waiting is the option.
4. Generic entry points keep the operation names, such as
   `guarantee_case[I](...)`, beside the synchronous free functions.
5. The pair probe (`probes/pair_cost.mojo`, O3, 100,000 pairs per sample)
   measured about 6.8 µs per leaf `both` against 10.7 µs for a fiber pair when
   children finish at once, and about 16 against 15 µs when each child yields
   once; per-child slot and registration setup dominates both. Decided: 10b
   moves `both`, `race`, and `race_first` onto fibers, preserving their
   documented semantics, so fibers are the one child-draining policy.
6. The synchronous family is an alias over the generic `ReaderT`, below the
   synchronous finalization module, so it cannot implement the traits without an
   import cycle. Its provider is a separate dictionary, `SyncIO[E]`, with
   `Family = IO[E]`; `Async[E]` remains its own provider.

### Pass 10 progress

**10a** was built on 2026-10-30: the `Defer`, `Raise`, `Cancel`, and `Spawn`
capabilities, both providers, the generic entry points, and the law suites.

- **Traits.** The four traits live in `fp.effects.protocols`, beside `Ask` and
  `Stateful`: associated carrier types per operation, admission predicates, and
  static methods. `Cancel` also gained `restore`, which applies a region's
  poll; the poll identity law needs it. Its associated names avoid the
  existing types: `RegionPoll` for the poll and `Forever` for `never`'s
  carrier.
- **Providers.** `Async[E]` implements all four by forwarding to `IO`'s
  operations; `guarantee_case` and `uncancelable` gained private bodies the
  public methods and the provider share. `SyncIO[E]` in `finalization.mojo`
  forwards to the synchronous functions and adds a deferred recipe, `_IODefer`,
  for `defer`. Both dictionaries are `not Deinitable`: they are never values,
  and this keeps `canceled[SyncIO[Int]]()` from matching the synchronous
  `canceled[E]()`.
- **Entry points.** Mojo rejects one name imported from two modules, so each
  generic entry point lives in the module that already owns the synchronous
  function of that name: `delay`, `canceled`, `uncancelable`, and `restore` in
  `_io_core.mojo`; `guarantee`, `on_cancel`, and `guarantee_case` in
  `finalization.mojo`. `defer`, `raise_error`, `start`, `join`, `cancel`,
  `never`, and `cede` live in `capabilities.mojo`.
- **Clients.** `capability_cancel` runs one generic program over `Defer`,
  `Raise`, and `Cancel` on both providers with identical outcomes and
  finalizer counts. `capability_spawn` covers generic `defer` on both and the
  spawn operations on `Async`. `cancel_laws` checks poll identity, guarantee,
  finalizer order, `on_cancel`, and canceled bodies on both, and raise/recover
  on `Async`. `spawn_laws` checks joined success, failure, and cancellation, a
  fully masked fiber, and records owner draining. `capability_family` defines
  a `Defer` and `Raise` test family; `reject_capability_narrow` rejects
  `canceled` on it, `public_reject_spawn_sync` rejects `start` on `SyncIO`, and
  `public_reject_raise_type` rejects a raised value of another type.

**10b** was built on 2026-10-30: `race_pair`, and `both`, `race`, `race_first`,
and the timeouts moved onto fibers as decided.

- **`race_pair`.** It starts both sides as fibers of the running fiber; a leaf
  waits for the first record to finish, checking the left first so it wins a
  tie, and the winner is joined through the ordinary join, so the joiner race
  stays covered. A caller canceled while waiting cancels both and completes
  only after both finish. Each arm is a `RaceWinner` with the winner's outcome
  and the loser's handle: Mojo moves neither tuple elements nor single fields
  out of a value, so the struct offers `take_outcome` and a consuming
  `into_loser`.
- **One child policy.** `both`, `race`, and `race_first` start both sides as
  fibers and wait in one private leaf, `_PairJoin`, whose policy cancels the
  other side once one finishes (races) or once one ends unsuccessfully
  (`both`), forwards the parent's request when observed, and combines through
  the canonical `_winner`, `_loser`, `_finish`, and `_zip_outcomes` only after
  both finish. Timeouts start the source as a fiber; `_TimeoutJoin` anchors the
  deadline on its first poll, at wrapper entry, and a bind afterwards keeps the
  value or runs the fallback. The typed `_Pair`, `Both`, `ScopedBoth`, `Race`,
  and `Timeout` machines are gone with their composition helper `_Selected`.
- **Recorded changes.** A root poll ticks every ready fiber once, so a pair no
  longer polls exactly one child per poll, and both sides enter in the first
  tick; after an immediate failure the sibling may already have entered, and
  it is canceled and drained before the pair completes. Scoped pairs, whose
  children borrowed a resource on every poll, have no fiber form and are
  removed with their clients' sections.
- **Clients.** `fiber_race_pair` covers left and right winners, ties, failing
  winners, and caller cancellation. `racing`, `selection_policies`,
  `timeouts`, `racing_origins`, `workload`, `async_finalization`, `io_engine`,
  `callbacks`, `erased_storage`, and `async_masking` pass unchanged through
  test helpers that lift machines into `IO`; `children`, `scheduler`, and
  `wakes` state the new tick granularity, and `children` and `origins` drop
  their scoped-pair sections. The pair rejections now check the public `IO`
  methods.

**10c** was built on 2026-10-30: `Supervisor`.

- **Shape.** A `Resource` cannot host a supervisor: `Resource` runs its
  acquire, use, and release phases as nested `IO`s inside a scope leaf, and
  each nested `IO` hosts and drains its own fibers, so a supervisor acquired
  that way would be drained as acquisition finished. Decided in review:
  `Supervisor[E].scoped(body, await_on_release=False)` instead, the
  counterpart of Cats Effect's `Supervisor(...).use`, running on the caller's
  run loop. It is not composable with `Resource.flat_map`.
- **Implementation.** A deferred head starts a parked supervisor fiber in the
  caller's host, owned by the caller; the body is bound to the `Supervisor`,
  and release is installed as its `guarantee` finalizer. `supervise` queues the
  program through the supervisor's host inbox with the supervisor fiber as its
  owner, through `_spawn_into`, which `start` now shares. Release stops the
  parked program, so the existing owner draining cancels and drains the
  supervised fibers; awaiting release first waits for them. Supervising after
  release aborts.
- **Clients.** `fiber_supervisor` covers a supervised fiber outliving the fiber
  that started it, release canceling a live fiber and waiting for its cleanup,
  awaiting release against the canceling default, and joining a supervised
  fiber.

**10d** was built on 2026-10-30: the forwarding audit and the selections it
admits.

- **ReaderT environment escape.** The audit found a memory-safety bug.
  `ReaderT` binds and combines run the base operation with continuations that
  keep a pointer to the borrowed environment. A typed base keeps that origin in
  the result type, so the environment outlives its uses; `IO[T, E]` erases its
  callbacks, so a `ReaderT[Async[E], R]` program could run after the
  environment was freed, and a probe crashed. Decided in review: reject it at
  compile time. `_ReaderContinue`, `_ReaderRight`, and `_ReaderFoldStep` are
  borrowed views, which `IO` already refuses as callbacks, so running such a
  bind over `Async` fails to compile; `ask`, `lift`, `map`, and `run` still
  work, and programs bind in the base after running the reader.
  `reject_reader_environment_escape` and `reject_lift_defer_reader` compile
  without the fix and are rejected with it.
- **Audit.** Decided scope: all four capabilities through `OptionalT` and
  `ResultT`; `Defer` and `Raise` through `ReaderT`, `StateT`, and `WriterT`.

  | Layer | `Defer` | `Raise` | `Cancel`, `Spawn` |
  |---|---|---|---|
  | `OptionalT`, `ResultT` | `delay` lifted, `defer` bound | lifted | forwarded: programs are base programs |
  | `ReaderT` | `delay` lifted; `defer` rejected over `Async` with every bind | lifted | excluded: finalizers and fibers would need the environment inside the `IO`, the same escape |
  | `StateT` | lifted and bound | lifted | excluded: state is lost on failure, and fibers cannot merge state lawfully |
  | `WriterT` | lifted and bound | lifted | excluded: the log is lost on failure and cancellation |

- **Selections.** `LiftDefer`, `LiftRaise`, `LiftCancel`, and `LiftSpawn` in
  `fp.effects.capabilities` follow `LiftAsk`: the destination layer, then the
  base's dictionary, with `I.Base == C.Family`. Operations that produce values
  lift the base's carrier through the layer's `lift`, which cannot fail over
  `Async`; `defer` binds the factory after a unit, through the existing
  `_IgnoreInput`. A private marker, `_CarrierLifting`, names the layers whose
  carriers are base carriers and their wrapped payload (`Optional[A]`,
  `Result[A, E]`); `OptionalT` and `ResultT` conform, and `LiftCancel` and
  `LiftSpawn` check it, because `downcast` does not check conformance.
  `LiftSpawn` delegates its `Cancel` members to `LiftCancel`. Like the
  providers, the dictionaries are `not Deinitable`, which keeps
  `delay[LiftDefer[...]]` from matching the synchronous `delay[E]`.
- **Recorded differences.** A layer's absence or stored error is a base
  success. It runs `guarantee` finalizers, as Cats Effect's transformer
  instances do, but a case finalizer cannot tell it from a success:
  `ExitCase` never exposes success payloads, so `guarantee_case` takes the
  base's case finalizer with the base exit. Finalizers for `guarantee` and
  `on_cancel` are the layer's unit programs, their own absence or error
  discarded through the base `map`. A fiber of `OptionalT[Async[E]]` with
  success type `T` is a `Fiber[Optional[T], E]`; joining it produces absence
  inside a successful `Outcome`, lifted into the layer. `raise_error` raises the
  base's domain error, not `ResultT`'s stored error. Generic programs that need
  several capabilities through a layer take one selection per capability, such
  as `[D: Defer, K: Cancel]`.
- **Clients.** `capability_lifting` covers `delay`, `defer`, and `raise_error`
  through every layer over `Async`; one generic program run on `Async` and
  through `OptionalT`; finalizers on absence and stored errors; `on_cancel` with
  a lifted cancellation; masked regions; and start, join, cancel, `never`, and
  `cede` through `OptionalT` and `ResultT`. `reject_lift_cancel_reader` and
  `reject_lift_spawn_state` reject the excluded layers.

## Pass 11 proposal

Pass 11 adds generic access to shared state and time over the existing owners,
specifies identity and clock domains, and makes virtual time and external event
delivery controllable in tests. This proposal follows an inventory of those
owners and of Cats Effect's derived operations; nothing has been built.

### Current state

- **Coordination.** `fp.effects.async_runtime` has `Deferred[T: Copyable]`,
  `Queue[T]` (bounded, positive capacity), and `Semaphore`. Each wraps the
  synchronous owner of the same name in `fp.effects.coordination`, built on
  one lock-guarded cell and its transitions (`_RefModify`, `_RefInspect`), so
  there is one implementation of each state change. Waiting operations suspend
  on the owner's signal (`Wait.changed`); guard contention, possible only when
  another thread holds the guard, yields once and retries. There is no async
  `Ref`: only the synchronous `Ref[T]`, with non-raising `modify`, borrowing
  `inspect`, `get` for copyable state, `update`, `set`, and `get_and_set`, as the
  [Pass 7b table](#public-surface) deferred it to this pass. No owner promises
  waiter fairness: when a signal wakes several waiters, the run loop's slot
  order decides; queued elements stay FIFO.
- **Synchronous waiting.** The synchronous `Ref` lock and `Deferred.get` loop
  with 1 ms sleeps, honest blocking for the synchronous family but blocking the
  thread. `IO.eval_io` runs a synchronous program inside one poll, so a
  blocking synchronous wait or `sleep_io` stalls the cooperative host.
- **Time.** `Duration` is checked nonnegative nanoseconds; `Instant` is an
  opaque point compared only within one clock origin. A root's `Clock` is the
  system monotonic clock or a shared manual clock, read by the host with `now`
  and advanced with `advance_to`; machines read it through `IOContext.now`.
  `IO.sleep`, `timeout_to`, and `timeout_after` anchor deadlines on entry. A
  program cannot read the time as an `IO`, and nothing measures a duration.
  The synchronous `sleep_io` measures the system clock even when its context
  inherits a manual one. The standard library has no wall-clock source
  (`std.time` offers `monotonic` and performance counters; `std.time.time` is
  a module), so wall-clock time would need a C library call, which this plan
  does not authorize.
- **Stepping.** `Driver.poll` reports `Progress`: completion, readiness, the
  earliest live deadline, and quiescence, meaning nothing runnable and no
  deadline. Tests advance a manual clock by hand between polls (`io_stepping`,
  `instant_timers`). Quiescence does not distinguish a program awaiting an
  external callback from one that can never resume, because the runtime does
  not count live external registrations. The blocking `run` idles with a fixed
  1 ms sleep whatever the next deadline; Pass 12 owns replacing it.
- **Identity.** There is no unique token; fiber identity stays private (Pass 9).

### Ownership audit of derived operations

| Cats Effect operation | Here | Ownership constraint | Proposal |
|---|---|---|---|
| `Ref.of`, `get`, `set`, `update`, `modify`, `getAndSet` | Synchronous `Ref` | Updates consume the state; raising updates are rejected because they would lose it; `get` copies | An async `Ref` over the same cell; `get` keeps requiring `Copyable` |
| `getAndUpdate`, `updateAndGet` | None | Return a copy of the old or new state | Copyable state only, derived from `modify` |
| `tryUpdate`, `access` | None | Optimistic versions; updates here are already serialized | Excluded |
| `Deferred.get`, `complete` | Async and synchronous `Deferred` | Every reader gets its own copy | Unchanged; one move-only hand-off uses a `Queue` |
| `memoize` | None | `IO` is move-only and runs once, so a result shared by many callers needs `Copyable`; Cats Effect restarts a canceled first run, which needs a factory | Review question 4 |
| `sleep`, `timeoutTo` | `IO.sleep`, `timeout_to`, `timeout_after` | The fallback is consumed once | Generic forms |
| `timeout` | None | The timeout error is an owned `E` value, consumed once | Derived from `timeout_to` |
| `Clock.monotonic`, `timed` | `IOContext.now` for machines only | The measured value moves through | `IO.monotonic`, `timed` |
| `delayBy`, `andWait` | None | None | Derived from `sleep` |
| `Clock.realTime` | None | No pure-Mojo source | Excluded and recorded |
| `Unique.unique` | None | Tokens must not expose fiber identity | Review question 3 |
| `CountDownLatch`, `CyclicBarrier`, `Mutex`, `AtomicCell` | None | Derivable from `Ref` and `Deferred` | Out of scope |
| `parTraverseN`, `parReplicateAN` | None | Collection operations | Excluded, as the plan requires |

### Proposal

1. **Async `Ref`.** `fp.effects.async_runtime.Ref[T]` wraps the synchronous
   `Ref`'s cell and transitions, as `Deferred` and `Queue` do: `get`, `set`,
   `update`, `modify`, `get_and_set`, `inspect`, `get_and_update`, and
   `update_and_get`, each an `IO` with the error chosen per call. Updates run
   once under the guard and never suspend, so they need no waiting machine.
2. **Capabilities.** Following the Pass 10 pattern, dictionaries with associated
   handle and carrier types, generic entry points, and provider forwarding:
   - `Concurrent` (`GenConcurrent`), extending `Spawn`: `make_ref`,
     `make_deferred`, and access to their handles. `ref` is a Mojo keyword, and
     `get`, `put`, and `modify` already name `Stateful` operations, so entry
     points carry the handle in their names: `get_ref`, `set_ref`,
     `update_ref`, `modify_ref`, `complete_deferred`, `get_deferred`. Creation
     is an effect, so each run of a program gets fresh state. Provider:
     `Async[E]`.
   - `Timing` (Cats Effect's `Clock`; that name is taken by the host clock):
     `monotonic` and `timed`. Providers: `Async[E]` and `SyncIO[E]`, both reading the context
     clock.
   - `Temporal` (`GenTemporal`), extending `Concurrent` and `Timing`: `sleep`,
     `timeout_to`, `timeout_after`, `timeout`, `delay_by`, and `and_wait`.
     Provider: `Async[E]`. `SyncIO` stays narrower: a blocking sleep is not a
     suspension.
   - Forwarding through `OptionalT` and `ResultT` as in 10d: creation, reads,
     and `sleep` are lifted, and timeouts forward their base programs.
3. **Clock domains.** One clock per root, inherited by every fiber, sleep,
   timeout, and `monotonic` read in it. `Instant` values compare only within
   that origin; a manual clock never moves unless the host or the test control
   advances it. The synchronous `sleep_io` keeps measuring the system clock and
   is documented as blocking the host under `eval_io`. Wall-clock time is
   recorded as unsupported.
4. **Unique identity.** If included, `unique[I]()` returns an opaque `Token`,
   compared only for equality, drawn from a process-wide counter, and unrelated
   to fibers: providers `Async[E]` and `SyncIO[E]`.
5. **Test control.** `TestControl[P]`, after Cats Effect's, owns a `Driver`
   with a manual clock:
   - `tick` runs until nothing is runnable without advancing time, and
     `tick_one` takes one root poll.
   - `advance(duration)` and `next_interval` move virtual time.
   - `tick_all` alternates ticking and advancing to the next deadline until the
     program completes or no deadline remains.
   - `results` returns the outcome once the program completes.
   - `is_deadlocked` is quiescence with no live external registration, which
     needs a registration count in the host. As in Cats Effect, it assumes the
     host delivers no other events, such as completing a `Deferred` it shares.

   External events, from `Completion.complete` or from a shared owner,
   delivered between ticks are observed at the next tick in delivery order. The
   promised orderings are written down, not randomized: queued elements are
   FIFO, a fiber's binds run in order, and `race_pair` checks the left side
   first. The ready-fiber order is unspecified. Seeded exploration of that
   order and replay traces remain Pass 14 qualification.
6. **No polling.** Every new waiting operation suspends on a signal or a timer,
   so a waiting program reports `runnable == False` and spends no transitions
   until woken.

### Steps

1. **11a:** the async `Ref`, `Concurrent` with its entry points, and the laws.
2. **11b:** `IO.monotonic` and `timed`, `Timing`, `Temporal`, the clock-domain
   documentation, and forwarding through `OptionalT` and `ResultT`.
3. **11c:** `TestControl`, the external-registration count, and the event
   ordering record.
4. **11d:** the approved derived operations (`unique`, `memoize`) and the audit
   table in its final form.

### Gate and clients

From the delivery table: reproducible manual-time and cancellation laws that
respect the promised event ordering, no polling loop presented as suspension,
and no async collection API additions.

- `capability_concurrent`: `Ref` reads after writes, `modify` atomic with
  respect to other fibers, `Deferred` completing once with every reader getting
  the value, and fresh state on each run of a program, on `Async` and through
  `OptionalT`.
- `temporal_laws` under `TestControl`: `sleep(a)` then `sleep(b)` advances
  `monotonic` by `a + b`; `timeout_to(never, d, f)` equals `sleep(d)` then `f`;
  a value completing before the deadline wins; a canceled sleep completes
  without advancing time; `monotonic` never decreases.
- `test_control`: `tick` versus `tick_all`, `next_interval`, deadlock against
  awaiting an external callback, and events delivered between ticks in order.
- Suspension checks: a waiting `Ref`-guarded, `Deferred`, `Queue`, or timer
  program reports no runnable work and runs no transitions until woken.
- Rejections: `Temporal` and `Concurrent` on `SyncIO`, `get_ref` on move-only
  state, and `Concurrent` through `ReaderT`.

### Review questions

1. **Names.** `Concurrent`, `Timing`, and `Temporal` for the capabilities, and
   handle-qualified entry points such as `get_ref` and `complete_deferred`; or
   other names?
2. **`Ref` operations.** The proposed set, including `get_and_update` and
   `update_and_get` for copyable state; or only the synchronous `Ref`'s current
   operations?
3. **`Unique`.** Add `unique[I]()` with a process-wide equality-only token, or
   keep identity out as Pass 10 did?
4. **`memoize`.** Add `IO.memoize` for copyable results, either without
   restarting after a canceled first run or with a factory that can rebuild
   the program; or leave it out?
5. **`TestControl`.** A public type in `fp.effects.async_runtime` with Cats
   Effect's names and its deadlock assumption; or only Driver helpers such as
   advancing to the next deadline?
6. **10d follow-ups.** Keep out of Pass 11 a layer-specific exit type for
   `guarantee_case` and a combined dictionary that selects several
   capabilities through one layer? Recommendation: keep them out.

### Pass 11 review decisions

Decided on 2026-10-31:

1. The capabilities are `Concurrent`, `Timing`, and `Temporal`, with
   handle-qualified entry points such as `get_ref` and `complete_deferred`.
2. `get_and_update` and `update_and_get`, for copyable state, are added once to
   the shared synchronous `Ref`, which the async `Ref` wraps. Generic code gets
   `get_ref`, `set_ref`, `update_ref`, and `modify_ref`; `tryUpdate` and
   `access` stay out.
3. `Unique` stays out: nothing in the library needs it, and a process-wide
   counter would be the runtime's first global mutable state. Identity is
   specified as absent until a consumer needs it.
4. `memoize` stays out, with its constraints kept in the audit table. A future
   version takes a factory that can rebuild a canceled first run.
5. `TestControl` is a public type in `fp.effects.async_runtime`, with Cats
   Effect's names and its documented deadlock assumption.
6. The 10d follow-ups stay out of Pass 11.
7. **Layering.** `IO` names `Async[E]` as its family, `Async` must name the
   handle types it provides, and their methods return `IO`, so the three must
   share a module or form an import cycle. No cycle is introduced: the async
   `Ref` and `Deferred` live in `engine.mojo` beside `IO` and `Async`, as the
   `Spawn` handle `Fiber` does, and the private machines that run one guarded
   update or wait for a change move to a module below it, which `Queue` and
   `Semaphore` in `coordination.mojo` also use. Public import paths do not
   change.

### Pass 11 progress

**11a** was built on 2026-10-31: the async `Ref` and the `Concurrent`
capability.

- **Layering.** As decided, `Ref` and `Deferred` live in `engine.mojo` beside
  `IO` and `Async`. The private `_attempt`, `_Once`, and `_Await` moved to
  `_async/attempts.mojo`, below the engine, and `Queue` and `Semaphore` in
  `coordination.mojo` use them from there. Public import paths are unchanged.
- **`Ref`.** It wraps the synchronous `Ref`'s cell and transitions: `get`,
  `set`, `get_and_set`, `update`, `modify`, `inspect`, `get_and_update`, and
  `update_and_get`, each an `IO` built from one guarded attempt. The two new
  operations were added once to the synchronous `Ref` through the existing
  private `_Update`, which now also yields a copy of the previous or next state.
  Library callbacks must not be borrowed views, and native callbacks are plain
  functions only: the synchronous `Ref` accepts closures because its typed
  recipes keep their origins, but an erased `IO` would not, so closures are
  rejected as for other `IO` callbacks.
- **`Concurrent`.** The trait in `fp.effects.protocols` extends `Spawn` with
  handle types, carriers, admission predicates for updates, and static
  operations. `Async[E]` provides it with `Ref` and `Deferred`; creation is an
  `IO.delay`, so each run allocates fresh state. The entry points in
  `fp.effects.capabilities` infer the state type from the handle, because Mojo
  1.2 resolves arguments left to right and cannot type the handle from a later
  callback's `Arg`; reads and `make_deferred` take it explicitly, as `join`
  does.
- **Clients.** `capability_concurrent` covers set, modify, and get through the
  entry points; one hundred updates from four interleaved fibers; two waiting
  readers and a losing second completion; fresh state on each run; library
  callables and plain functions; `Ref`'s own operations, including move-only
  state; and a parked `Deferred` read that spends no polls or transitions until
  another root completes it. `test_coordination` covers the synchronous
  additions. `public_reject_concurrent_sync`, `public_reject_ref_get_move_only`,
  and `public_reject_ref_closure` reject `Concurrent` on `SyncIO`, reading
  move-only state, and a capturing closure.
- **Remaining.** Forwarding `Concurrent` through `OptionalT` and `ResultT`
  arrives with 11b, as the steps order it.

**11b** was built on 2026-10-31: `Timing`, `Temporal`, the clock domains, and
forwarding through the layers.

- **`IO` operations.** `IO.monotonic()` reads the root's clock through a leaf
  that calls `IOContext.now`. `timed`, `timeout`, `delay_by`, and `and_wait`
  join `sleep`, `timeout_to`, and `timeout_after`; `timeout` is `timeout_to`
  with a raised error. To make readings usable, `Instant.since` measures the
  `Duration` between two readings, clamped to zero and to the largest
  supported duration, and `Duration.to_nanoseconds` reads one.
- **One implementation of each derived operation.** `fp.effects._timing`
  derives `timed`, `delay_by`, and `and_wait` through a family and its clock
  reading or sleep, as Cats Effect does. `IO`, `Async`, `SyncIO`, and the
  layer selections all use it, so through `OptionalT` a layer's absence has
  no duration and skips the sleep after it, as Cats Effect's `OptionT` does.
  Each dictionary names a small private clock or sleep source rather than
  itself: a `Timing` member defined through the dictionary's own `Timing`
  conformance is a recursive declaration in Mojo 1.2, which `mojo doc`
  reports even when builds pass.
- **Capabilities.** `Timing` (`monotonic`, `timed`) is provided by `Async[E]`
  and by `SyncIO[E]`, through a recipe that reads the context's clock.
  `Temporal`, extending `Concurrent` and `Timing`, is provided by `Async[E]`
  only. Entry points: `monotonic`, `timed`, `sleep`, `timeout_to`,
  `timeout_after`, `timeout`, `delay_by`, and `and_wait`.
- **Clock domains.** Recorded in the guide: one clock per root, `Instant`
  compared only within it, no wall-clock reading, and `sleep_io` measuring
  the system clock and blocking the host under `IO.eval_io`.
- **Forwarding.** `LiftConcurrent` and `LiftTemporal` forward through
  `OptionalT` and `ResultT`, checked by `_CarrierLifting`: handles are the
  base's, creation and reads are lifted, and timeouts forward the layer's
  programs. `LiftTiming` works through every layer, like `LiftDefer`; over
  `Async`, running a timed `ReaderT` program is rejected with every `ReaderT`
  bind. `LiftTemporal` reads the same lifted clock as `LiftTiming` through
  that clock source.
- **Clients.** `capability_temporal` drives programs on a manual clock,
  advancing it to each next deadline: `sleep(a)` then `sleep(b)` takes
  `a + b`; `timeout_to(never, d, f)` runs `f` after `d`; an earlier value
  wins; `timeout_after`, `timeout`, `delay_by`, and `and_wait`; a canceled
  sleep completes without advancing time; `monotonic` never decreases;
  `SyncIO` timing; and forwarding through `OptionalT`, `StateT`, and
  `WriterT`. `public_reject_temporal_sync` and `reject_lift_temporal_state`
  reject `Temporal` on `SyncIO` and through `StateT`.

**11c** was built on 2026-10-31: `TestControl`, the external-registration
count, and the event-ordering record.

- **`TestControl`.** A public type in `fp.effects.async_runtime`, beside
  `Driver`, with Cats Effect's names: `tick`, `tick_one`, `advance`,
  `advance_and_tick`, `next_interval`, `tick_for`, `tick_all`,
  `is_completed`, `is_deadlocked`, `request_cancel`, and `results`. It owns a
  `Driver` on a manual clock at zero and is linear like it, so `results`
  consumes a completed program. Observations poll with a zero budget, which
  only reports status.
- **External registrations.** The root's shared `_Budget` counts live
  `IO.async` registrations: a `Callback` counts itself from a successful
  registration until it selects a completion or cancellation, and its
  destructor releases the count if it is torn down first. `is_deadlocked` is
  quiescence with no live registration. As in Cats Effect, it assumes no other
  events arrive: a program waiting on a `Deferred` the test could still
  complete also reports a deadlock, which the guide documents.
- **Event ordering.** Recorded in the guide. The proposal said events
  delivered between ticks are observed in delivery order; that holds within
  one fiber, but when several fibers become ready together the run loop's
  slot order decides, so it is recorded as unspecified with waiter order. The
  promised orderings are a fiber's own steps, FIFO queue values, the left side
  of a race finishing in the same tick, and every `Deferred` reader receiving
  the value. Seeded exploration of the unspecified orders stays in Pass 14.
- **Clients.** `test_control` covers virtual sleeps, `tick` against
  `advance`, `tick_one`, `tick_for`, a read that nothing can complete
  reporting a deadlock and then resuming when the test completes it, two
  `IO.async` registrations that are not deadlocked and complete together at
  the next tick after the test delivers both events, and cancellation of
  `never`. `capability_temporal` now runs its laws through `TestControl`
  instead of its own virtual-time loop, and the guide gains the runnable
  example `async_test_control`.

**11d** was completed on 2026-10-31: the audit in its final form and the
Pass 11 gate. As decided, it adds no operations: `Unique` and `memoize` stay
out.

| Cats Effect operation | Delivered | Ownership rule |
|---|---|---|
| `Ref.of`, `get`, `set`, `update`, `modify`, `getAndSet` | Async `Ref`; `make_ref`, `get_ref`, `set_ref`, `update_ref`, `modify_ref` | Updates consume the state and cannot raise; reads copy, so `get` needs copyable state; callbacks own their state, and native ones are plain functions |
| `getAndUpdate`, `updateAndGet` | Both `Ref`s, from one private `_Update` | Copyable state only |
| `tryUpdate`, `access` | Excluded | Updates are already serialized |
| `Deferred.get`, `complete` | Async `Deferred`; `make_deferred`, `complete_deferred`, `get_deferred` | Every reader receives a copy; a move-only hand-off uses a `Queue` |
| `memoize` | Out (decision 4) | A shared result needs copyable values; restarting a canceled first run needs a factory |
| `sleep`, `timeoutTo`, `timeout` | `IO` and `Temporal` | The fallback or error is consumed once |
| `Clock.monotonic`, `timed` | `IO.monotonic`, `timed`; `Timing` on `Async` and `SyncIO` | The value moves through; a failure has no duration |
| `delayBy`, `andWait` | `IO` and `Temporal`, derived once in `fp.effects._timing` | Through a layer, absence skips the sleep after it |
| `Clock.realTime` | Excluded | No pure-Mojo wall-clock source |
| `Unique.unique` | Out (decision 3) | No consumer; fiber identity stays private |
| `TestControl` | `TestControl` | Linear: `results` consumes a completed program |
| `CountDownLatch`, `CyclicBarrier`, `Mutex`, `AtomicCell` | Out of scope | Derivable from `Ref` and `Deferred` |
| `parTraverseN`, `parReplicateAN` | Excluded | Collection operations |

- **Gate: manual-time and cancellation laws.** `capability_temporal` checks
  the sleep, timeout, and delay laws through `TestControl` with exact
  virtual durations, a canceled sleep that leaves time unchanged, and
  monotonic readings; `test_control` checks deadlock, delivery between ticks,
  and cancellation; the `MonadCancel` and `GenSpawn` laws are Pass 10's. The
  promised orderings are recorded in the guide, and every check depends only
  on them. Met for the single-threaded cooperative host; seeded exploration of
  the unspecified orders remains Pass 14 qualification.
- **Gate: no polling loop presented as suspension.** Every async waiting
  operation, `Deferred.get`, `Queue` offers and takes, `Semaphore.acquire`,
  sleeps, and timeouts, suspends on a signal or a timer: the parked read in
  `capability_concurrent` spends no polls or transitions until woken, and a
  sleeping program under `TestControl` has nothing to run. Recorded
  exceptions: guard contention yields once and retries, which only another
  thread holding a guard can cause; the synchronous family's waits block the
  thread in 1 ms steps, honest blocking that is why `SyncIO` is not
  `Temporal`; and the blocking `run` idles in 1 ms steps until Pass 12
  provides waiting.
- **Gate: no async collection API additions.** None were added.
- **Coverage after Pass 11.** Against the [coverage
  table](#generic-capability-coverage): deferred construction and errors,
  cancellation, spawn, concurrent state, and monotonic time with sleeping and
  timeouts are provided, for `Async[E]` and, where honest, `SyncIO[E]`, and
  forward through `OptionalT` and `ResultT`. Unique identity and wall-clock
  time are absent, as recorded. Blocking and interruptible execution,
  execution-context access, and foreign-thread delivery belong to Pass 12.
  Passes 8 through 11 form the first useful advanced-runtime milestone. Each
  pass ran targeted qualification; the full verification gates (step 3e) have
  not run and wait for a request.

## Pass 12 proposal

Pass 12 integrates the runtime with POSIX hosts: a root parks instead of
polling on a timer, other threads can complete its work and wake it, blocking
calls run on worker threads, file descriptors can be awaited, and wall-clock
time is available. Each root still runs its fibers on one thread; Pass 13
builds the multi-threaded runtime on this foundation. This proposal replaces
an earlier draft that assumed no direct operating-system calls; it was
rewritten after the review decisions below. Nothing has been built.

### Pass 12 review decisions

Decided on 2026-10-31:

1. **Operating-system interfaces.** The library may call POSIX interfaces
   directly where that improves the user's experience; pure Mojo stays
   preferred where it suffices. The target is POSIX systems: Linux is
   qualified now, macOS later.
2. **Poller.** POSIX `poll()` with a self-pipe, for portability. epoll and
   kqueue may follow behind the same interface when measurements justify them.
3. **Values that cross threads.** Plain names such as `IO.blocking`, with the
   caller's obligation documented, as for `unsafe_start`: Mojo has no Send or
   Sync proof.
4. **`interruptible`.** Cats Effect's semantics without POSIX signals: on
   cancellation the function sees a cancellation request and is woken from any
   wait it makes through the library, and cancellation completes when it
   returns. Cats Effect sends `Thread.interrupt` and also waits for the
   function to return; Scala Native's interrupt sets a flag, unparks the
   thread, and wakes a sleep through a self-pipe, without signals, so it does
   not wake a thread blocked in `read()` either. Erlang's alternative, letting
   observers move on while native work finishes in the background, would
   conflict with owners waiting for their fibers, and is not adopted.
5. **File descriptors.** A low-level readiness API for library authors in
   `fp.effects.async_runtime.protocols`; no socket or TCP API in the public
   interface.
6. **Threading.** A multi-threaded work-stealing runtime is worth building for
   Cats Effect parity: Cats Effect's default runtime and the BEAM both run one
   scheduler per logical processor. It becomes Pass 13, with a payload
   thread-safety contract; the qualification pass becomes Pass 14.
7. **macOS** is deferred; POSIX compatibility is the goal now.
8. **Host notifier.** An erased notifier given to `Driver`'s constructor, so
   `Driver[P]` keeps its type; the host asserts its thread safety.
9. **Blocking pool ownership.** Each root owns a pool started on first use and
   may borrow one shared by several roots; there is no process-wide default.
10. **Capability.** A `Blocking` capability with `blocking[I]` and
    `interruptible[I]`, provided by `Async[E]` through the pool and by
    `SyncIO[E]` inline.

### Current state

- **Host boundary.** `Driver.poll` is nonblocking and reports completion,
  readiness, the earliest deadline, and quiescence. The blocking `run` drives
  the same `Driver` and idles in 1 ms sleeps, whatever the next deadline, so an
  idle program still wakes a thousand times a second and a timer can be late by
  up to 1 ms. `TestControl` drives a manual clock. A host learns that an
  external event made the root runnable only by polling.
- **Notification state.** `Signal`, wake registrations, `Completion`
  admission, `CancellationToken`, and the manual clock keep their state behind
  atomic spin locks, and wake registrations are generation-checked, but none of
  it is qualified across threads; `Signal`'s documentation disclaims
  cross-thread use. `CancellationToken.cancel` notifies a `Signal`, so a
  canceled waiter wakes through the same path as any external event.
- **Threads.** `unsafe_start` starts a Linux OS thread with `pthread_create`
  for the synchronous family and puts every thread-safety obligation on the
  caller. The synchronous coordination owners are qualified under contention
  from such threads (`test_coordination`). The async run loop, its fibers, and
  every `IO` value are confined to the polling thread.
- **Missing operations.** Of Cats Effect's `Sync` and `Async`: `blocking`,
  `interruptible`, `interruptibleMany`, `realTime`, `evalOn`, `startOn`,
  `backgroundOn`, and `executionContext`.

### Proposal

1. **Execution profiles.** One matrix, in the guide and the scheduler page:

   | State | Profile | Rule |
   |---|---|---|
   | Run loop, fibers, `IO` values, `Ref`/`Deferred`/`Queue`/`Semaphore` operations, `Driver`, `TestControl` | Confined to the root's polling thread | Never touched from another thread |
   | `Signal`, wake registrations, `Completion` admission, `CancellationToken`, manual `Clock`, the poller's wake | Shared notification state | Safe from any thread; locks give each operation a total order |
   | Payloads moved by `Completion.complete`, functions and results moved to and from blocking workers | Transferred once under a lock | The caller asserts the value may move to, and be destroyed on, the other thread |
   | Blocking worker threads | Owned by a blocking pool | Run one function at a time; never touch a run loop |

   Locks stay on in every profile; eliding them for proven thread confinement
   is a measured optimization, not a semantic change.
2. **Host services.** A root owns its run loop, wake registry, budget, and
   poller. It borrows its clock, cancellation token, and host notifier, and
   either owns a blocking pool, started on first use, or borrows one shared by
   several roots. Finishing a root retires its registrations, closes what it
   owns, and waits for its in-flight blocking calls, since their callers wait
   for them; it never stops a borrowed service. A late notification from
   another thread finds a stale generation and does nothing. The
   execution-context contract for Pass 12 is one context per root, the thread
   that polls it; Pass 13 adds the compute pool that `evalOn` and its
   relatives can target.
3. **Notification from other threads.** Qualify `Signal.notify`,
   `Completion.complete`, and `CancellationToken.cancel` from threads other
   than the polling thread:
   - **Ordering.** Everything the notifying thread wrote before the call
     happens before the polling thread's continuation that observes it,
     because both sides pass through the same lock.
   - **Wake before park.** A notification between the polling thread reading a
     revision and parking is not lost: registration compares revisions under
     the lock, and the root's wake hook interrupts a parked poller.
   - **Payload transfer.** `complete` moves the outcome into the completion
     under its lock; the polling thread takes it under the same lock. A late or
     duplicate payload is destroyed on the calling thread, outside the lock.
   - **Teardown with producers in flight.** A completion delivered after its
     registration was withdrawn, or after the root finished, is rejected and
     wakes nothing.
4. **Polling system.** After Cats Effect's `PollingSystem`, a private interface
   with one POSIX implementation:
   - `poll(timeout)` waits on the registered descriptors and a self-pipe, with
     the timeout to the next deadline or none, and reports ready descriptors,
     an interrupt, or expiry.
   - `interrupt()` is safe from any thread: it sets an atomic flag and writes
     one byte to the pipe only when the flag was clear, so wakes coalesce; the
     poller drains the pipe and clears the flag before the next poll.
   - Descriptors are registered for read or write interest; a registration is
     removed when its waiter completes or is canceled.
   - The pipe's ends are nonblocking and close-on-exec, set through `fcntl`
     for portability.
   - `poll()` waits in whole milliseconds. A deadline less than 1 ms away is
     waited with `nanosleep`, which can delay an external wake by under 1 ms.
5. **Root wake hook.** The wake registry reports, from whichever thread
   notifies, when an external event makes the root runnable. The hook
   interrupts the root's poller, or calls the host notifier when a `Driver` is
   embedded in an application's own loop. The notifier must be nonblocking,
   callable from any thread, and must not reenter the `Driver`; it is never
   called after `finish` returns, and `finish` waits for a call in progress.
6. **`run` parks.** `run` polls the `Driver` while work is runnable, then waits
   in the poller until the next deadline, an external wake, or a ready
   descriptor. An idle program uses no CPU, and a program that can never
   continue waits forever, as in Cats Effect.
7. **Blocking pool.** After Cats Effect's blocking execution context and
   Erlang's dirty I/O schedulers:
   - `IO.blocking(f)` runs an owned function on a worker thread and resumes the
     fiber with its result through a `Completion`. Like Cats Effect's, it
     cannot be canceled; a timeout waits for it.
   - `IO.interruptible(f)` passes the function an interruption handle. On
     cancellation the handle reports the request, and waits made through it,
     such as sleeping or waiting for a descriptor, wake at once; cancellation
     completes when the function returns. Cats Effect's `interruptibleMany`
     repeats a one-shot interrupt; a cancellation request here stays visible,
     so it needs no separate operation.
   - Workers start on demand, idle threads are reused and retired after a
     timeout, and a configurable maximum bounds them.
   - Thread creation, joining, and the platform check move from `unsafe_start`
     into one private owner that both use.
   - Functions follow the `IO` callback rule: owned library callables and plain
     functions, never closures or borrowed views.
8. **Descriptor readiness.** `await_readable[E](fd)` and
   `await_writable[E](fd)`, free functions in
   `fp.effects.async_runtime.protocols`, return an `IO` that registers interest
   with the root's poller and suspends until the descriptor is ready;
   cancellation removes the registration. The caller owns the descriptor and keeps it open
   and nonblocking. Library authors build pipes, sockets, or process I/O on top;
   no socket API is published.
9. **Wall-clock time.** `real_time` reads `clock_gettime(CLOCK_REALTIME)` and
   returns nanoseconds since the Unix epoch, in a small wall-clock type, since a
   `Duration` holds at most about 31 years. `Timing` gains it for `Async` and
   `SyncIO`; under `TestControl` it starts at the epoch and moves with virtual
   time, as in Cats Effect.
10. **Provider matrix.** The guide lists every Cats Effect `Sync` and `Async`
    operation with its provider, or with its exact obligation: `evalOn`,
    `startOn`, `backgroundOn`, and `executionContext` until Pass 13; macOS
    until it is qualified.

### Steps

1. **12a:** the execution profiles and host-service contract; qualification of
   `Signal`, `Completion`, and `CancellationToken` from other threads; the root
   wake hook.
2. **12b:** the polling system, `run` parking, and the host notifier.
3. **12c:** the blocking pool with `blocking` and `interruptible`, and the
   shared OS-thread owner.
4. **12d:** descriptor readiness, wall-clock time, and the provider matrix.

### Gate and clients

From the delivery table: every advertised `Sync` and `Async` operation has a
real provider and tests on Linux; wake before park, publication, owned and
borrowed teardown, and cancellation of blocking work pass; nothing polls on a
timer where it could park; remaining gaps are published with their exact
obligation.

- `foreign_completion`: an OS thread completes an `IO.async` registration
  while the host polls or parks, many times with varied delays on both sides;
  every program completes within a bound, so no wake is lost, with the value
  written before the call; late and duplicate completions are rejected.
- `foreign_signal`: an OS thread notifies a `Signal` a custom leaf waits on and
  cancels a token a waiting fiber observes; data written before the call is
  visible after it.
- `poller`: interrupts racing a park, coalesced interrupts, descriptor
  readiness on pipes, registrations removed on completion and cancellation,
  and closing.
- `run_parks`: an idle `run` uses almost no CPU over a long sleep, measured
  with `getrusage`, and timers fire close to their deadlines.
- `host_notifier`: the notifier runs on external wakes only, never after
  `finish`, and `finish` waits for an in-flight call.
- `blocking_pool`: blocking work runs on another thread while other fibers keep
  running; results and errors return; a timeout waits for `blocking`; an
  interrupted function wakes from a wait and cancellation completes after it
  returns; idle workers are reused and retired; finishing a root waits for its
  calls.
- `descriptor_readiness` and `real_time` cover the remaining operations, and
  the stress harness gains cross-thread wake scenarios.
- Rejections: closures given to `blocking`, and `interruptible` handles used
  outside their function.

### Review questions

1. **Notifier shape.** An erased notifier given to `Driver`'s constructor, so
   `Driver[P]` keeps its type, or a type parameter `Driver[P, N]`?
   Recommendation: erased, with the host asserting its thread safety.
2. **Blocking pool ownership.** Each root owns a pool started on first use and
   may borrow a shared one, or one process-wide default pool? Recommendation:
   per root with an optional shared pool, which avoids a global singleton and
   gives teardown a single owner.
3. **Capability.** Add a `Blocking` capability with `blocking[I]` and
   `interruptible[I]`, provided by `Async[E]` through the pool and by
   `SyncIO[E]` inline, since the synchronous family already blocks its thread?
   Recommendation: yes, matching Cats Effect, where both belong to `Sync`.

## Pass 13 proposal

Pass 13 makes the runtime multi-threaded: fibers run in parallel on a
work-stealing pool after Cats Effect's, and the single-threaded runtime remains
as a profile of the same scheduler. Large refactoring is expected; the end
result is what matters. Nothing has been built.

### Current state

- **Fibers belong to a host.** The entered `IO` that ran the first `start`
  hosts every fiber beneath it in one table of slots (`_Fibers` in
  `fibers.mojo`). Its run loop ticks ready fibers inside its own poll, so a
  fiber never runs except when its host is polled, and all of them run on the
  root's thread. An `IO` inside a lifted leaf hosts its own fibers.
- **Ownership lives in the table.** Each entry counts its live children and
  holds a finished fiber's outcome until they drain; completion walks owners
  in the table. `Supervisor` starts fibers into the same table with the
  supervisor fiber as owner. `Driver.fibers()` snapshots the table.
- **One wake registry per root.** `_Runtime` in `waking.mojo` is a tree of
  generation-checked nodes behind one lock: every leaf slot of every fiber
  registers under its parent, wakes propagate ready flags to the root, and the
  host dequeues ready children in FIFO order. It also holds the root's timer
  heap. Every wake and every timer takes the same lock.
- **Per-root accounting.** `_Budget`, which counts transitions, carries the
  failure reporter, and counts live `IO.async` registrations, is confined to
  the root's thread.
- **Platform.** Mojo 1.2's `Atomic[T]` takes explicit `Ordering` arguments
  (acquire, release, acquire-release, sequential) and provides `fence`;
  `ArcPointer` counts references atomically. Threads come from `pthread_create`
  through external calls, as `unsafe_start` already does. There is no Send or
  Sync proof.

### Design

1. **Fibers become scheduled tasks.** A fiber is a task with an atomic
   scheduling state (idle, scheduled, running, notified while running, done),
   its run loop, and its record. It runs on one worker at a time; between runs
   its state is an owned value in a queue, so moving it between workers moves
   ownership and needs no shared mutable access.
   - **Wakes.** Each fiber has its own wake registry, the existing tree scoped
     to the fiber's nested leaves, so wakes for different fibers never contend.
     The registry's root wake hook, Pass 12's hook generalized from a root to
     any fiber, moves the task from idle to scheduled and pushes it: onto the
     current worker's queue when woken on a worker, otherwise onto the external
     queue, then wakes a parked worker if needed. A wake while running sets
     the notified state, so the worker requeues the fiber instead of parking it.
   - **Ownership.** Owner draining moves from the host table into fiber records:
     a record counts its live children atomically, and an owner whose program
     finished cancels its children and waits on its record's signal until the
     count is zero. Held outcomes, joins, claims, delivery, and exactly-once
     reporting keep their protocols, which are already signal-based.
   - **Supervisor and nested hosts.** A supervised fiber's owner is the
     supervisor fiber's record. Fibers started inside a lifted `IO` belong to
     the fiber running it; there is no separate host table anywhere.
   - **Diagnostics.** Each worker keeps a bounded registry of its live fibers'
     metadata, without payloads; `Driver.fibers()` merges them.
2. **One scheduler, two profiles.** The same scheduler runs with one worker on
   the calling thread, the current-thread profile, or with a pool of workers,
   the work-stealing profile. The current-thread profile replaces today's host
   table, keeps a deterministic FIFO order, and serves `TestControl` and
   `Driver` embedding. There is one implementation of fibers, wakes, timers,
   and ownership.
3. **Work-stealing pool**, following Cats Effect's `WorkStealingThreadPool`:
   - One worker per online logical processor by default, from `sysconf`.
   - A fixed-capacity, lock-free local ring per worker with one producer and
     many consumers. When full, half of it moves to the external queue in
     batches; stealers take half of a victim's queue.
   - The work-finding order: own queue, external queue, then, with permission
     to search, expired timers of other workers and half of another worker's
     queue, scanning from a random worker. At most half the workers search.
   - Parking in the worker's own poller from Pass 12, on its self-pipe, with
     the timeout to the worker's next timer; one mechanism serves wakes,
     descriptors, and timers. A parked worker is woken when work arrives, no
     worker is searching, and not all are active.
   - Fairness: the transition budget becomes per worker; a fiber that exhausts
     it goes to the back of its worker's queue, and a worker checks the
     external queue periodically so outside submissions are not starved.
4. **Timers per worker.** A fiber sleeping on a worker registers in that
   worker's heap, which only its owner changes. Cancellation from another
   thread marks the node and counts it; the owner removes marked nodes when
   they reach half the heap. Workers may run other workers' expired timers
   while searching. The generation checks of the wake registry carry over.
5. **Blocking hand-off.** `blocking` on a compute worker hands the worker's
   local queue to a cached or new replacement thread and runs the call inline,
   as Cats Effect's `prepareForBlocking` does; afterwards the thread offers
   itself for reuse and exits after an idle timeout. `interruptible` uses the
   same hand-off with Pass 12's interruption handle. Pass 12's separate
   blocking pool remains for the current-thread profile.
6. **Runtime lifecycle.** A `Runtime` value owns the workers: it is created
   from `IORuntimeConfig`, runs programs, and on shutdown cancels and drains
   its fibers, then joins its threads. `run(program)` with the work-stealing
   profile creates a runtime for the call; long-running applications create
   one and run many programs on it.
7. **Payload thread safety.** The contract: everything stored in an `IO`, in
   fiber state, or moved through a `Completion` must be safe to move to, and
   be destroyed on, another thread, and fibers share mutable state only through
   `Ref`, `Deferred`, `Queue`, `Semaphore`, or types their authors
   synchronize. Sharing an `ArcPointer` to unsynchronized mutable data between
   fibers becomes a data race, and the guide says so prominently, with the
   current-thread profile as the alternative. The pass audits every shared
   structure in the runtime (erased boxes, records, signals, registries,
   coordination cells, completions, tokens, clocks, budgets, reporters),
   researches compile-time rejection of payloads known to be thread-confined,
   such as raw pointers found by reflection, and adopts Send and Sync if Mojo
   adds them.
8. **Memory ordering.** Every lock-free structure documents the ordering of
   each atomic operation and why; stress tests exercise each with many threads,
   and a thread sanitizer runs if the toolchain supports one.
9. **Promises restated.** A fiber's own steps stay ordered, queues stay FIFO,
   and every `Deferred` reader receives the value. Under parallel execution,
   "the left side wins a tie in the same tick" becomes "the first completion
   observed wins"; the current-thread profile keeps the deterministic tie.

### Steps

1. **13a:** measurements and the concurrent structures in isolation: the local
   ring, the external queue, the per-worker timer heap, and parking, each with
   multi-thread stress tests; atomic costs against the 50–60 ns run-loop step.
2. **13b:** fibers as scheduled tasks on the current-thread profile: per-fiber
   wake registries, ownership in records, `Supervisor`, diagnostics, and
   `TestControl`, with the host table removed and every existing client green.
3. **13c:** the work-stealing pool: workers, stealing, parking in pollers, wakes
   from any thread, and fibers running in parallel.
4. **13d:** per-worker timers and polling, the blocking hand-off, and the
   `Runtime` lifecycle and configuration.
5. **13e:** the thread-safety contract, the audit, long stress runs, restated
   promises, and documentation.

### Gate and clients

From the delivery table: fibers run in parallel with the same outcomes, laws,
and ownership guarantees; the runtime's own structures are race-free under
stress; throughput and latency are measured against the single-threaded
runtime; `TestControl` stays deterministic.

- Every existing fiber, capability, law, and coordination client runs on both
  profiles.
- `wstp_parallel`: CPU-bound fibers speed up with more workers.
- `wstp_queues` and `wstp_timers`: the ring, external queue, and timer heap
  under many threads, including cross-thread timer cancellation.
- `wstp_wakes`: no lost wake under storms of wakes from workers and foreign
  threads; parked workers wake for new work.
- `wstp_ownership`: owner draining, joins, races, and `Supervisor` across
  workers, with each failure reported exactly once.
- `wstp_blocking`: a blocking call hands off its worker's queue and other
  fibers keep running.
- `wstp_shutdown`: a runtime cancels, drains, and joins its threads, leaving
  nothing running.
- Stress and soak runs of randomized spawn, join, cancel, and wake mixes, and a
  measured comparison with the current-thread profile.

### Pass 13 review decisions

Decided on 2026-10-31, as recommended below:

1. `run` uses the work-stealing profile by default once 13e lands, with the
   thread-safety contract documented and the current-thread profile one
   setting away.
2. An explicit `Runtime` value owns the workers; `run` creates one per call,
   and there is no process-wide default runtime.
3. `Driver` embeds the current-thread profile only; the work-stealing profile
   is driven through `Runtime`.
4. Wave 1 of the combined plan starts in separate cloud sessions, one per
   stream, with this session as integrator.

Decided on 2026-10-31, after S7's research
([Async payload thread safety](async-thread-safety.md)):

5. **Payload check and marker.** 13e adopts one compile-time check, once it
   has measured the elaboration cost and listed the library types the check
   rejects. A payload is rejected when its field tree reaches a raw or
   borrowed `Pointer` through a struct outside the standard library, unless
   that struct conforms to a public marker trait named `ThreadTransferable`.
   The marker is the author's explicit claim, and it gives way to Mojo's `Send`
   and `Sync` if they arrive. `ArcPointer` is not rejected by default. An
   opt-in `assert_thread_transferable[T]()` covers shared ownership, and the
   library's synchronized owners conform to the marker.
6. **Scope.** The check lives once in the canonical erasure owner,
   `_Erased.__init__`, so it applies to the synchronous and async families
   alike. Besides threads, it closes the borrowed-pointer gap that erasure
   cannot check today (`erased_borrow.mojo`). This is a behavior change:
   synchronous programs whose own structs hold raw pointers must conform to
   the marker.

Decided on 2026-10-31, after Wave 1, for the races S7 found:

7. **Supervising after release.** A `supervise` that loses a race with the
   supervisor's release returns a fiber that is already canceled, and its
   program never runs. This replaces the documented abort, which parallel
   execution would make nondeterministic, and matches "starting observes
   cancellation". It is a behavior change.
8. **Stream S8 (13c-0).** The race fixes run as their own stream in a separate
   session, before Wave 2.
9. **Lock-free terminal state.** Uncontended, a lock costs one atomic
   read-modify-write, as a lock-free step does. The risks of locks are
   elsewhere:
   - a lock shared by every worker serializes them;
   - a preempted holder stalls everyone who needs the lock;
   - user code can run under a lock;
   - `_lock` sleeps for 1 ms when contended.

   Cats Effect is lock-free on its hot paths. BEAM uses fine-grained locks
   but keeps them uncontended through ownership. S8 therefore builds:
   - **A one-shot slot.** An atomic state word over a slot with a single
     owner: one thread writes the value and publishes it, and whoever wins
     the next atomic step owns it exclusively. Fiber records and `Completion`
     share it, which gives exactly-once destruction of move-only outcomes
     without a lock.
   - **A closable lock-free stack.** Starts push with a compare-exchange
     unless the stack is closed, and release closes it with one exchange.
     The supervisor and the scopes' child lists share it.
   - **Sharding instead of synchronizing.** The transition slice belongs to
     the executor, the external-registration count is one atomic on the
     scheduler, and fiber start and end take no per-root lock.

   `_lock` spins and then yields instead of sleeping. Wake registries keep
   their locks, as do `Ref`, `Queue`, and `Semaphore`: Cats Effect's
   lock-free `Ref` retries a pure function over copyable state, which would
   change our public contract for move-only state. 13c measures them under
   the pool.
10. **Measure first.** S8 begins with a probe comparing the one-shot slot and
    the stack with their locked versions: uncontended, contended, and with
    more threads than cores.
11. **Performance gates** (decided after S8's first measurements). In a storm
    where every thread completes one slot, S8's first lock-free one-shot was
    20–30% slower than a spin lock, because every losing thread wrote the
    contended cache line. The lock-free design is kept, as the better final
    architecture:
    - it needs fewer atomic writes per operation;
    - a worker never waits on a descheduled thread, but parks its fiber;
    - a re-entrant completion simply loses instead of deadlocking.

    Its implementation must meet these gates:
    - **Read before writing.** A party that can see it has lost leaves after
      one plain read, and only a plausible winner performs a read-modify-write.
    - **Placement.** Contended words sit on their own cache lines.
    - **Allocation.** Operations allocate nothing; a node or slot is allocated
      at most once per owner.
    - **Realistic benchmarks.** The fiber pair, the run-loop step, a completion
      from another thread, a join racing a completion, and many fibers starting
      under one scope must show no regression beyond run-to-run noise against
      `nightly`.
    - **Contended microbenchmarks.** Each must be at least as fast as its
      spin-lock baseline, from 1 to 16 threads.

    A primitive that still fails after tuning uses a lock that spins on reads
    and then yields, built on the shared `_acquire_lock`, with the reason
    recorded.
12. **Wave 2 alongside S8.** S2 and S6 start while S8 is still running.
    - S2 shares no files with S8.
    - S6 builds only on `Completion`'s public behavior and the shared lock
      helpers, and merges after S8.
    - The waits in `interruptible`'s handle, its interruptible sleep and its
      descriptor waits, are built on S2's poller rather than on a second
      self-pipe mechanism. S6 therefore adds them after S2 merges.
13. **S6's public API** (approved on 2026-10-31).
    - **`Interruption`.** The handle, neither copyable nor movable, is borrowed
      by the function given to `IO.interruptible`. It offers `requested()`,
      with `sleep` and descriptor waits after S2.
    - **Entry points.** `IO.blocking` takes `IO.delay`'s overload set.
    - **Capability.** `Blocking` with `Blocked`, `BlockingCompatible`,
      `Interrupted`, and `InterruptibleCompatible`; `LiftBlocking`; and the
      free functions `blocking[I]` and `interruptible[I]`.
    - **`BlockingPool`.** A copyable pool whose copies share one pool, with at
      most 64 workers by default and a 60 s idle timeout. It has no `close()`:
      a pool lives as long as its copies, and when the last copy is dropped it
      drains its calls and joins its workers.
    - **Sharing.** One field, `IORuntimeConfig.blocking_pool`. With none
      given, the root creates a private pool with the defaults, which closes
      when the root finishes. A bounded pool can deadlock when more calls than
      its maximum wait on each other; the guide says so.

### Review questions

1. **Default profile.** Should `run` use the work-stealing profile by default,
   as Cats Effect does, once 13e lands? It changes behavior for existing code
   that shares unsynchronized state between fibers. Recommendation: yes, with
   the contract documented and the current-thread profile one setting away.
2. **Runtime ownership.** An explicit `Runtime` value, with `run` creating one
   per call, or a lazily created process-wide default, as Cats Effect's global
   runtime? Recommendation: explicit, which avoids the first global singleton
   and gives shutdown one owner.
3. **Embedding.** Keep `Driver` for the current-thread profile only, with the
   work-stealing profile driven through `Runtime`? Recommendation: yes; a host
   that owns its loop embeds the current-thread profile.

## Passes 12 and 13 together

The two passes share foundations: Pass 12's operating-system layer, poller,
wake hook, and blocking pool are exactly what Pass 13's workers park in, wake
through, and hand off to. Planned together, their work splits into streams that
separate agents can build in parallel, each on its own branch, owning its own
files, and passing its own targeted qualification before an integrator merges
it into `nightly`.

### Streams

| Stream | Content | Owns | Depends on |
|---|---|---|---|
| **S1 OS layer** (merged) | External calls for `pipe`, `pipe2`, `fcntl`, `poll`, `read`, `write`, `close`, `clock_gettime`, `getrusage`, and the thread owner extracted from `unsafe_start` | New `src/fp/_internal/os.mojo`; `src/fp/effects/fibers.mojo` | None |
| **S2 Poller** | The polling interface and its `poll()`-and-self-pipe backend, with registration, coalesced interrupts, and closing (12b's core) | New `_async/polling.mojo` | S1 |
| **S3 Cross-thread qualification** (merged) | `Signal`, `Completion`, and `CancellationToken` from other threads: ordering, wake before park, payloads, teardown (12a) | New clients; documentation in `waking.mojo` and `callbacks.mojo` | None; uses `unsafe_start` |
| **S4 Concurrent structures** (merged) | The local ring, external queue, per-worker timer heap, and parking protocol, with stress tests and measurements (13a) | New `_async/scheduling/` modules and clients | S1 for threads, or `unsafe_start` until it lands |
| **S5 Engine refactor** (merged) | Fibers as scheduled tasks on the current-thread profile, per-fiber wake registries with the wake hook, ownership in records, `Supervisor`, diagnostics, the host notifier (13b, 12a's hook) | `engine.mojo`, `fibers.mojo`, `supervisor.mojo`, `kernel.mojo`, `waking.mojo` | None |
| **S6 Blocking** | The blocking pool, `blocking`, `interruptible` with its handle, and the `Blocking` capability (12c) | New `_async/blocking.mojo`; additions to `protocols.mojo` and `capabilities.mojo` | S1, S3 |
| **S7 Thread-safety research** (merged) | The payload contract, the audit list, and research on compile-time rejection by reflection (13e's research) | Plan and design notes | None |
| **S8 Race fixes (13c-0)** | The one-shot slot and the closable stack; fiber records, `Completion`, the supervisor, and scopes on them; the budget split; the fiber table without a per-root lock; `_lock` without sleeps (decisions 7–10) | New `_internal` primitives; `fibers.mojo`, `supervisor.mojo`, `callbacks.mojo`, `_io_core.mojo`, `kernel.mojo`, `executor.mojo`, the budget code in `engine.mojo`, the scheduler in `waking.mojo`, `host.mojo`, `_lock` in `coordination.mojo` | Wave 1 |

### Waves

1. **Wave 1, in parallel:** S1, S3, S4, S5, and S7. They touch disjoint files,
   except that S3's documentation edits in `waking.mojo` and `callbacks.mojo`
   merge before S5 reaches them.
2. **Wave 1b:** S8, the race fixes. Wave 2 starts alongside it (decision 12).
3. **Wave 2, in parallel:** S2 after S1, and S6 after S1 and S3. S6 adds its
   `IO` methods to `engine.mojo` after S5 merges, as a small rebase.
4. **Wave 3, integration:** `run` parking in the poller through the wake hook,
   descriptor readiness, wall-clock time, and the provider matrix (12b and 12d
   on top of S2 and S5), then the Pass 12 gate.
5. **Wave 4:** the work-stealing pool (13c and 13d) on S2, S4, S5, and S6, then
   13e's audit and stress runs and the Pass 13 gate.

S5 is the critical path: it is the largest change and every later wave builds on
it, so it starts first and is never split between agents. S1, S3, S4, and S7 are
small and independent enough to finish early, so Wave 2 can start while S5
continues.

### Working agreement for parallel agents

- Each stream works on its own branch from `nightly`, owns the files listed,
  and adds rather than edits shared files such as `qualify.py`, `protocols.mojo`,
  and `capabilities.mojo`.
- Generated contracts (`public-exports.json`, `api.json`), the export and
  example counts in `test_docs.py`, and this plan's progress sections are
  regenerated or written by the integrator at merge time, which removes the
  most frequent conflicts.
- Each stream runs targeted qualification of the clients it touches before
  asking to merge; the integrator rebases, re-runs the overlapping clients, and
  pushes, one stream at a time.
- Mojo builds are memory-heavy: two concurrent qualification jobs are the limit
  in one container. Parallel agents should run in separate cloud sessions,
  each with its own container, or at most two at a time here.
- The full verification gates (step 3e) run after Wave 3 and after Wave 4.

### Passes 12 and 13 progress

**S1** (Wave 1) was merged on 2026-10-31: the private POSIX layer,
`fp._internal.os`.

- **Contents.** Owned descriptors (`OwnedFd`, closed exactly once), `Pipe`
  with a self-pipe constructor and byte-level `wake` and `drain`, `fcntl` flag
  helpers, `read`, `write`, `close`, `poll` over `PollFd` entries,
  `clock_gettime` with `realtime_nanoseconds`, `getrusage` for process and
  thread CPU time, and the thread owner `OSThread`. Failures raise a typed
  `OSError` carrying the call's name and its `ErrNo`.
- **One owner per facility.** The standard library already owns monotonic time
  (`std.time.monotonic()`), the processor count
  (`std.sys.info.num_logical_cores()`), and sleeping (`std.time.sleep`), so the
  layer does not wrap `nanosleep` or `sysconf`. `poll` restarts after `EINTR`
  with the time remaining on `std.time.monotonic()`, the clock `Instant` reads,
  so poll timeouts and deadlines share one clock. The standard library has no
  public wall clock, so `CLOCK_REALTIME` is read here.
- **Threads.** `OSThread[S]` owns the state's `ArcPointer`, passes the body a
  pointer to it, and releases it only after joining exactly once, by `join` or
  when dropped; `join` returns the owner. `unsafe_start`'s `Fiber` is its first
  client, and the blocking pool and the work-stealing workers will use the
  same owner. `unsafe_start`'s signature, documentation, and errors are
  unchanged; only the abort text for a failed `pthread_join` now names the OS
  layer.
- **Self-pipe.** On Linux `pipe2` sets nonblocking and close-on-exec
  atomically. Other targets fall back to `pipe` and `fcntl`, which leaves a
  documented window in which a concurrent fork and exec inherits the ends.
  Merging repeated wakes into one byte belongs to the S2 poller.
- **Descriptor lifetime.** Mojo may destroy a value after its last use, and a
  raw descriptor copied into a `PollFd` does not extend its owner's life. Owners
  such as the poller therefore keep their `OwnedFd` values as fields.
- **Platforms.** Linux x86-64 constants and layouts were checked against glibc;
  the sizes of `struct pollfd` and `struct timespec` are asserted at compile
  time. macOS values are marked unverified, and `OSThread` is disabled there at
  compile time.
- **Qualification.** `os_layer` (new: pipe round trip, `EAGAIN` on empty
  nonblocking reads, poll readiness and timeout, both clocks, the processor
  count, `getrusage`, and thread start, join, and owner release), `test_fibers`,
  and `test_coordination` passed from source and from the package at O0 and
  O3: 12 of 12. The `EINTR` restarts are untested, since no test raises a
  signal.

**S3** (Wave 1) was merged on 2026-10-31: `Signal`, `Completion`, and
`CancellationToken` qualified from other threads.

- **Clients.** In both, OS threads started with `unsafe_start` act on a root
  that the main thread polls through `Driver`.
  - `foreign_completion` completes `IO.async` registrations from another
    thread:
    - a thousand rounds with randomized delays on both sides and no lost
      wake;
    - plain data written before `complete` is visible to the continuation;
    - accepted payloads are destroyed exactly once, on the polling thread;
    - duplicate, late, and withdrawn completions are rejected, and their
      payloads are destroyed on the completing thread;
    - completions race a real-time timeout, and all three results occur:
      accepted and used, rejected, and accepted then dropped by the
      withdrawal.
  - `foreign_signal` notifies `Signal`s and cancels `CancellationToken`s from
    another thread:
    - a notify lands at varied points between a leaf's revision read and its
      wait;
    - two waiters share one signal;
    - one to three notifies per round;
    - a cancellation wakes a parked leaf, a root in `never().guarantee`, or a
      root joining a waiting child.
- **Bug fixed.** `Completion.complete` documented that a rejected outcome is
  destroyed outside the lock, but Mojo destroyed it after its last use, inside
  the lock. A destructor that completed the same completion would then spin
  forever. The rejected outcome now moves into a local that is dropped after
  the unlock. The `callbacks` client records the lock state from a rejected
  payload's destructor: the check fails on the old code and passes now.
- **Contracts.** The docstrings of `Signal`, `Completion`, and
  `CancellationToken` now state their cross-thread contract: they are safe
  from any thread, writes before `notify`, `complete`, or `cancel` are visible
  to the observer, and rejected payloads are destroyed on the completing
  thread. `Completion` also states the caller's obligation that its value and
  error may be destroyed on either thread.
- **Notes for later streams.**
  - `IO.async`'s withdrawal runs after every entered registration, not only on
    cancellation as in Cats Effect. It is documented, and the guide's Cats
    Effect mapping should make the difference prominent.
  - A root that finishes while a foreign `notify` runs can have its wake state
    destroyed on that foreign thread, so S5 keeps that state free of anything
    tied to the polling thread.
  - Wake before park against a real poller waits for S2 and the wake hook.
- **Qualification.** The new clients took 70–84 s to compile, so `os_layer`,
  `foreign_completion`, and `foreign_signal` received 360 s compile timeouts.
  The S3 branch passed 8 of 8 (`foreign_completion` and `foreign_signal`); 200
  runs of each client at O0 and 200 at O3 passed, as did 300 runs under load.
  After the fix, `callbacks`, `foreign_completion`, `foreign_signal`, and
  `test_control` passed 16 of 16 from source and package at O0 and O3; the
  run's input check flagged only the plan and guide prose edited during it.

**S7** (Wave 1) was merged on 2026-10-31: the payload thread-safety research,
published as [Async payload thread safety](async-thread-safety.md).

- **Contract.** It proposes the guide's wording, following Rust's `Send` and
  `Sync`:
  - What must be safe to move between threads: everything stored in an `IO`,
    fiber state, `Completion` payloads, blocking functions and their results,
    and the values in `Ref`, `Deferred`, and `Queue`.
  - How fibers may share mutable state: through the synchronized owners,
    through types their authors synchronize, or through `ArcPointer` to
    immutable data.
  - What silently becomes a data race. The `thread_arc_race` probe lost about
    40% of 200,000 increments through a shared `ArcPointer[Int]`.
- **Audit.** It covers every runtime structure shared between threads and
  finds three races that only parallel execution exposes: `_FiberRecord`'s
  outcome and release state, `_SupervisorState` and `_Stop`, and
  `_Budget.registrations`. S5 was asked to fold the first two into its record
  rewrite; the budget goes with 13c's per-worker budgets. The integrator's
  review struck one finding: `Node`'s teardown only reads before releasing
  through `ArcPointer`'s own fenced drop, so it needs no extra fence.
- **Compile-time checks.** Reflection can walk field trees and find raw
  pointers and `ArcPointer` in user structs, `List`, and `Optional`. It cannot
  see pointer targets, origins, `Variant`, `Tuple`, or `Dict` values, or
  anything inside an erased `IO`. Mojo 1.2 has no `Send` or `Sync`; Modular's
  async design lists one as planned, without a date. Decisions 5 and 6 above
  adopt the narrow raw-pointer check with the `ThreadTransferable` marker for
  13e.
- **Open.** Coordination locks found held are retried at once. Whether to wait
  on the owner's signal instead is decided in 13c, from measurements. The
  thread sanitizer does not run for Mojo executables in this container, so
  design item 8's sanitizer run needs another host or a toolchain fix.

**S4** (Wave 1) was merged on 2026-10-31: the work-stealing pool's concurrent
structures in isolation (13a), in the private package
`fp.effects._async.scheduling`. Each module's docstring gives every atomic
operation's ordering and why it suffices (design item 8).

- **Local ring** (`_LocalQueue`, after `LocalQueue`):
  - 256 entries, with one producer (its owner) and many consumers.
  - The head word packs a steal tag and a real tag; the tags are 32-bit, which
    widens the ABA window from 2^16 to 2^32 operations.
  - A thief takes half the elements, and a full ring spills half to the
    external queue in batches of 32.
- **External queue** (`_ExternalQueue`, after `ScalQueue`):
  - Power-of-two stripes, each a `Deque` in a `_Cell` with a padded, published
    length, so consumers skip empty stripes without locking.
  - Each spilled batch goes to its own random stripe, as `ScalQueue.offerAll`
    does with upstream's batch arrays, and a refill takes up to one batch from
    one stripe.
- **Timer heap** (`_TimerHeap`, after `TimerHeap`):
  - The heap is owner-only, and each node carries a generation-tagged state
    word. A single compare-exchange picks the one taker of each payload: the
    owner firing it, a thief, or a canceler. Upstream tolerates a duplicate
    run, but these payloads are move-only.
  - Cross-thread cancellations are counted and packed by the owner.
  - Storage never moves while other threads may read it.
  - The earliest-deadline hint, the size, and the canceled count each sit on
    their own cache line.
- **Parking** (`_Parking`, after `WorkStealingThreadPool`'s state and
  `notifyParked`):
  - This is the state machine only. The operating-system park and unpark
    belong to S2's poller.
  - One word packs the active and searching counts, and each worker has a
    parked flag that one notifier claims by compare-exchange.
  - Searchers are bounded at half the workers exactly, by compare-exchange,
    where upstream checks then increments.
  - The last parking searcher and every submitter run a sequentially
    consistent handshake, so no submitted work is lost.
  - Upstream's last-searcher test compares the whole word with 1, which an
    active caller never matches; this module tests the searching count.
  - Follow-up for 13c: a waking worker spins without yielding while its
    notifier finishes the unpark.
- **Shared lock.** `fp._internal.cells` gained one acquire and release
  implementation, shared by the existing `_Guard` (`_try_lock`,
  `_lock_metadata`, whose orderings and yields are unchanged) and a new
  borrowed `_CellGuard` (`_lock_cell`). The borrowed guard uses acquire and
  release ordering, needs no reference counting, and spins 256 times before
  yielding. The external queue uses it, and `Signal` and the coordination
  owners can migrate later.
- **Measurements** (O3, four cores, ns per operation):

  | Operation | ns |
  |---|---|
  | Ring enqueue and dequeue pair | 14 |
  | Per element stolen or spilled | 17–19 |
  | External push and pop pair, uncontended | 31–33 (75–81 with `_lock_metadata`) |
  | External pair, four threads on four stripes | 1,080–1,150 (1,460–1,600 before) |
  | Timer insert and poll, 1,000 queued | 58–61 |
  | Timer insert and poll, two threads stealing | 230–300 (410–460 before padding) |
  | `fetch_add`, compare-exchange, sequentially consistent store or fence | 6–9 |

  Removing bounds checks from the owner's heap arrays took timer insert and
  poll from about 182 to 58 ns.
- **Clients.**
  - `wstp_support`, `wstp_queues`, and `wstp_timers` check that every element
    is received at most once (exactly once when drained) and destroyed exactly
    once, and that steals, spills, and cross-thread cancellations happened.
  - `wstp_parking` runs four `OSThread` workers with a test-only self-pipe
    parker. It checks the searcher bound, one unpark per parking, and that no
    work is lost. Without the last searcher's re-check it fails on every run.
  - `WSTP_SCALE` multiplies the workloads for soaks.
  - The branch soaked 755 parking, queue, and timer runs at O0 and O3 with no
    failure.
- **Qualification.**
  - The S4 branch passed 28 of 28: the four clients plus `foreign_signal`,
    `foreign_completion`, and `callbacks`.
  - At merge, the same four clients with `foreign_signal` and `callbacks`,
    which exercise the changed lock code, passed 24 of 24 from source and
    package at O0 and O3.
  - No thread sanitizer runs here (see S7).

**S5** (Wave 1) was merged on 2026-10-31: 13b, fibers as scheduled tasks on
the current-thread profile, with Pass 12's host notifier. Wave 1 is complete.

- **Tasks.** Every fiber and the root program are tasks (`_TaskHeader`) with
  an atomic state: idle, scheduled, running, notified while running, or done.
  A queue entry is the right to run a task, and only its holder touches the
  task's body. The new `_async/executor.mojo` runs them. One root poll is one
  executor turn: queued tasks run in FIFO order, each at most once, while the
  transition budget lasts, and a task requeued during the turn waits for the
  next one. The ready queue sits behind a small `_TaskQueue` interface, which
  S4's ring and external queue can implement in 13c.
- **Per-fiber wake registries.** Each task has its own registry, the existing
  generation-checked tree. When the registry's root list fills, its hook
  schedules the task, or marks a running task notified. Whether a finished run
  requeues or parks is decided under the registry's lock, which every wake
  also takes, so no wake is lost. A shared per-root `_Scheduler` holds the
  ready queue, one timer heap of generation-checked wakers, the host notifier,
  and the table of live fibers. The locks are always taken in one order
  (registry, then ready queue; timers, then registry), so they cannot
  deadlock.
- **Ownership in records.** Each run loop that starts fibers has a scope that
  counts its live children atomically. A finished program's task cancels its
  children and waits on the scope's signal for the count to reach zero. Held
  outcomes, joins, claims, delivery, and exactly-once reporting keep their
  semantics, and a supervised fiber belongs to the supervisor fiber's scope.
  `_Fibers`, `_Inbox`, `_FiberHost`, and the per-host scheduling step are
  gone.
- **Host notifier** (Pass 12, decision 8). A new `Driver` constructor overload
  takes a repeatable, non-raising `Thunk`, so `Driver[P]` keeps its type.
  - The driver calls it only for wakes that arrive between polls, possibly
    from another thread.
  - It is never called after `finish` returns, and `finish` waits for a call
    in progress.
  - At integration, `notify_host` was changed to register its call before
    it reads the notifier, which `shutdown` clears once `close` returns.
- **Cross-thread borrows (found at integration).**
  - With that reorder, `foreign_completion` hung in about 60% of O3 runs and
    `foreign_signal` in about 25%, because `close` waited forever on a
    notification count stuck at 1 or -1.
  - The cause was that `_Scheduler`'s methods took `mut self` while other
    threads called them on the same object. A `mut` borrow is exclusive in
    Mojo, so the compiler may assume nothing else touches the struct during
    the call, and the atomics stored inline in it lost concurrent updates.
  - Ruled out:
    - a use-after-free: leaking every scheduler still hung, and
      AddressSanitizer was clean;
    - a stray store to a fixed offset: a canary there survived.

    Moving only that counter into its own allocation fixed both clients.
  - S5 then moved every atomic of `_Scheduler` and `_TaskHeader`, and the
    notifier, behind pointers to separate allocations. Every cross-thread
    method now takes immutable `self`, as the S4 structures already did. The
    rule is in the development guide's compiler practices.
  - Cost for 13c: each task makes one more small allocation, which a packed
    per-task atomic block can remove.
- **Teardown.** A finished root empties its timer heap, queue, fiber table,
  and notifier on the polling thread. This breaks the cycle through stale
  timer entries, which had leaked the scheduler, and keeps a late foreign
  wake from destroying the host's notifier on another thread. It answers
  S3's teardown note.
- **Behavior changes, accepted on review.**
  - `Driver.fibers()` lists every live fiber under the root, each with its
    owner, including fibers started by an `IO` lifted into a leaf and fibers
    under roots that are not an `IO`. Cats Effect's fiber dump does the same.
  - Fibers run in FIFO turns instead of the old, unspecified alternation
    between a root's program and its fibers. `spawn_laws` relied on that
    alternation; its `.map` now sits inside the masked region, so the law
    tests masking rather than scheduling order.
- **Deviations from the plan.**
  - An `IO` run as a leaf still drains the fibers it started before
    completing, which keeps the guide's promise that such a leaf runs with
    its own fibers.
  - Fiber state stays in the task header between runs, and the queue entry
    carries the right to run it. This gives the same exclusive access as
    moving the state through the queue.
- **Open for 13c.** S7's parallel races are not fixed here:
  - `_FiberRecord`'s `outcome`, `done`, and `released`;
  - `_SupervisorState` and `_Stop`;
  - the `_Budget` counters.

  Each needs one atomic or lock-guarded terminal decision before fibers run
  in parallel.
- **Measurements** (O3, against baseline binaries run back to back).

  | Measurement | Before | After |
  |---|---|---|
  | Fiber pair, both children done at once | 12–17 µs | 11–13 µs |
  | Fiber pair, each child yields once | 17–21 µs | 15–19 µs |
  | Run-loop step | 44–59 ns | 45–47 ns |

  Fiber pairs are about 10–15% cheaper, and the step is unchanged within
  noise.
- **Qualification.**
  - S5 swept all 93 positive and rejection clients from source and package at
    O0 and O3: 364 of 372 passed. The 4 `host_notifier` failures were an
    unused-variable warning in the new client, since fixed. The 4
    `reject_callback_error` failures were a stale fixture expecting a
    diagnostic that `callbacks.mojo` stopped emitting on 2026-10-29; the
    integrator updated it.
  - After rebasing, 27 overlapping clients passed 108 of 108.
  - After the fix, 200 O3 runs each of `foreign_completion`,
    `foreign_signal`, and `host_notifier` all passed.
  - At merge, `host_notifier`, `test_control`, `foreign_completion`,
    `foreign_signal`, `reject_callback_error`, `fiber_snapshot`,
    `spawn_laws`, `fiber_basics`, `fiber_supervisor`, and `callbacks` passed
    40 of 40 from source and package at O0 and O3.

## Implementation reference map

Use the following inspected snapshots, not moving branches:

- **Scala Native:** [`b961982edab83915bcbbda559117f0a89d2f3e10`](https://github.com/scala-native/scala-native/commit/b961982edab83915bcbbda559117f0a89d2f3e10),
  a development snapshot. Virtual-thread interfaces here are runtime internals,
  not a stable API or a requirement to implement stackful continuations.
- **Cats Effect:** [`de84c01f76b2f42fcee9d43aba66c82992add103`](https://github.com/typelevel/cats-effect/commit/de84c01f76b2f42fcee9d43aba66c82992add103),
  covering its shared effect interpreter, native platform setup, and test tools.

- **Scala Native threads (Passes 12–13):** [`eb3f3b85680c2913be221747fcb398e2b1f370ef`](https://github.com/scala-native/scala-native/commit/eb3f3b85680c2913be221747fcb398e2b1f370ef),
  the `main` branch inspected on 2026-10-31 for its POSIX thread
  implementation.

These snapshots were inspected independently; they are not a verified dependency
pair and neither becomes a dependency of FP Mojo. Follow the named symbols and
line links for the active pass. The Mojo contracts in this plan take precedence
over upstream implementation choices.

### Scala Native runtime references

| Passes | Source and entry points | Concrete lesson and adaptation boundary |
|---|---|---|
| 7, 12 | [VirtualThreadScheduler.scala](https://github.com/scala-native/scala-native/blob/b961982edab83915bcbbda559117f0a89d2f3e10/nativelib/src/main/scala/scala/scalanative/runtime/VirtualThreadScheduler.scala#L9): `execute`, `schedule`, `Cancellable`, `afterYieldOnCarrier` | Separate scheduling, delayed work, and host notifications. Adapt the service boundary to Mojo's owned/borrowed services; do not copy JVM-shaped virtual-thread or carrier assumptions. |
| 7, 12 | [LinktimeInfo.scala](https://github.com/scala-native/scala-native/blob/b961982edab83915bcbbda559117f0a89d2f3e10/nativelib/src/main/scala/scala/scalanative/meta/LinktimeInfo.scala#L8): `isMultithreadingEnabled`, `target`, platform predicates | Make execution-profile selection explicit. Use supported Mojo compile-time mechanisms; platform or single-thread selection is not proof that shared handles need no synchronization. |
| 12 | [Blocker.scala](https://github.com/scala-native/scala-native/blob/b961982edab83915bcbbda559117f0a89d2f3e10/nativelib/src/main/scala/scala/scalanative/runtime/Blocker.scala#L14): `apply`, `begin`, `end` | Pair entry/exit accounting for supported blocking regions, including failure. Scala Native inserts some calls through its compiler; our library must use explicit provider boundaries, with no compiler changes or assumption that marking a call makes it nonblocking. |
| 12–13 | [PosixThread.scala](https://github.com/scala-native/scala-native/blob/eb3f3b85680c2913be221747fcb398e2b1f370ef/javalib/src/main/scala/java/lang/impl/PosixThread.scala): `park`, `unpark`, `interrupt`, `sleepInterruptible` | Parking on a condition variable with a monotonic clock, and an interruptible sleep that waits in `poll()` on a self-pipe the interrupter writes to. The model for Pass 12's interruption handle and worker parking; interruption sets a flag and wakes library-level waits, without signals. |
| 8 baseline, 14 evaluation | [Zone.scala](https://github.com/scala-native/scala-native/blob/b961982edab83915bcbbda559117f0a89d2f3e10/nativelib/src/main/scala/scala/scalanative/unsafe/Zone.scala#L13): `alloc`, `close`, `Zone.acquire` | Give allocations an explicit owner and scope. Its raw allocation model does not establish Mojo payload destruction, origins, or prompt per-frame reclamation; retain those obligations when evaluating typed pools. |

### Cats Effect interpreter and native-host references

| Passes | Source and entry points | Concrete lesson and adaptation boundary |
|---|---|---|
| 7–8 | [IO.scala: flatMap](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IO.scala#L469), [defer](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IO.scala#L1296), and [FlatMap node](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IO.scala#L2236) | Compare stable outer `IO[A]` typing with heterogeneous internal steps. Use this to identify the representation problem; Scala's inheritance/erased references are not a Mojo storage proof. |
| 8 | [IOFiber.scala: runLoop](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L210), [succeeded](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L1210), and [failed](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L1270) | Trace continuation push/pop and return to the run loop. Upstream also uses bounded recursive fast paths via `MaxStackDepth`; do not mistake every helper for a loop or copy its casts. Prove all our runtime-owned unwind and disposal paths independently. |
| 8 | [IORuntimeConfig.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/unsafe/IORuntimeConfig.scala#L22), together with `IOFiber.runLoop` | Inspect `cancelationCheckThreshold`, `autoYieldThreshold`, and their validation. Borrow separate policies and accounting; determine thresholds from our transition costs rather than copying numeric defaults. |
| 9–10 | [IOFiber.scala: cancel/join](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L197), [prepareFiberForCancelation](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L1132), and [done](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L1092) | Follow cancellation through suspended finalizers to completion publication and execution-state release. Upstream caches a reusable join outcome; our exclusive move-only result transfer and unobserved-error accounting require their own design. |
| 7, 12 | [IORuntimeBuilder.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/unsafe/IORuntimeBuilder.scala#L26): `setCompute`, `setBlocking`, `setScheduler`, `addShutdownHook`; [native IORuntimeCompanionPlatform.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/native/src/main/scala/cats/effect/unsafe/IORuntimeCompanionPlatform.scala#L30): `createWorkStealingComputeThreadPool`, `createDefaultPollingSystem`, `createDefaultBlockingExecutionContext` | Study service assembly and teardown ownership separately from effect evaluation. Its pools and platform bindings are the model for Passes 12–13; values moved between threads still need this plan's documented transfer contract. |
| 7, 12 | [PollingSystem.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/jvm-native/src/main/scala/cats/effect/unsafe/PollingSystem.scala#L36): `makePoller`, `poll`, `processReadyEvents`, `needsPoll`, `interrupt`, `closePoller`, `PollResult` | Specify wait/interrupt/ready-batch lifecycle before choosing a provider. The interface alone does not prove a lost-wakeup-free handshake; qualify that protocol against our generation and revision owners. |
| 12 | [IOFiberPlatform.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/jvm-native/src/main/scala/cats/effect/IOFiberPlatform.scala): `interruptibleImpl`; [Sync.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/Sync.scala): `blocking`, `interruptible`, `interruptibleMany` | Cancellation of interruptible work completes only after the function returns; `blocking` is uncancelable. Adopt the semantics; replace `Thread.interrupt` with a cancellation handle that wakes the library's own waits. |
| 12 | [EpollSystem.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/native/src/main/scala/cats/effect/unsafe/EpollSystem.scala): `FileDescriptorPollerImpl`, `registerFileDescriptor`, `pollReadRec`, `interrupt`; [SleepSystem.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/jvm-native/src/main/scala/cats/effect/unsafe/SleepSystem.scala) | A descriptor-readiness API for library authors and the poller's interrupt through a file descriptor. Pass 12 uses `poll()` and a self-pipe behind the same kind of interface; epoll and kqueue ([KqueueSystem.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/native/src/main/scala/cats/effect/unsafe/KqueueSystem.scala)) are later backends. |
| 13 | [WorkStealingThreadPool.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/jvm-native/src/main/scala/cats/effect/unsafe/WorkStealingThreadPool.scala): `notifyParked`, `transitionWorkerToSearching`, `stealFromOtherWorkerThread`, `stealTimers`; [WorkerThread.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/jvm-native/src/main/scala/cats/effect/unsafe/WorkerThread.scala): `run`, `lookForWork`, `parkLoop`, `prepareForBlocking` | The work-finding order, the cap on searching workers, wake conditions, parking in the poller or on a condition variable, and the blocking hand-off of a worker's queue. Mojo's ownership must replace the JVM's shared references: a fiber's state moves between workers as an owned value. |
| 13 | [LocalQueue.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/jvm-native/src/main/scala/cats/effect/unsafe/LocalQueue.scala): `enqueue`, `dequeue`, `stealInto`; [LocalQueueConstants.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/native/src/main/scala/cats/effect/unsafe/LocalQueueConstants.scala); [ScalQueue.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/jvm-native/src/main/scala/cats/effect/unsafe/ScalQueue.scala) | A 256-entry lock-free ring with one producer and many consumers, stealing half, and spilling half to the external queue in batches of 32. Measure our own sizes; the atomics and their orderings need their own proof under Mojo's memory model. |
| 13 | [TimerHeap.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/jvm-native/src/main/scala/cats/effect/unsafe/TimerHeap.scala): `steal`, `packIfNeeded` | One timer heap per worker, changed only by its owner, with stealing of expired timers and deferred cleanup of cancellations made from other threads. Reuse the generation checks of our wake registry. |
| 9, 14 | [FiberInfo.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/FiberInfo.scala#L21): `state`, `trace`, `pretty`; [FiberMonitorShared.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/unsafe/FiberMonitorShared.scala#L21): `toFiberInfo`, `printFibers` | Borrow diagnostic vocabulary and presentation. `FiberInfo` explicitly retains the underlying fiber: our bounded snapshots must copy permitted metadata without retaining its payloads or execution graph. |

### Capability laws and deterministic qualification references

For Passes 7 and 10–12, start with the actual capability declarations:
[`MonadCancel`](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/MonadCancel.scala#L210)
and
[`GenSpawn`](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/GenSpawn.scala#L171).
The same [kernel directory](https://github.com/typelevel/cats-effect/tree/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel)
contains `GenConcurrent.scala`, `GenTemporal.scala`, `Clock.scala`,
`Sync.scala`, and `Async.scala`. Inspect required primitives before derived
conveniences; the concurrent collection functions remain outside this plan.

| Passes | Source and entry points | Concrete lesson and adaptation boundary |
|---|---|---|
| 7, 10, 14 | [MonadCancelLaws.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/laws/shared/src/main/scala/cats/effect/laws/MonadCancelLaws.scala#L24): `uncancelablePollIsIdentity`, `uncancelableFinalizers`, `canceledAssociatesLeftOverFlatMap` | Enumerate cancellation/masking equations before claiming an instance. Translate each into observable native outcomes and ownership events; record differences rather than weakening error/cancellation state to pass it. |
| 9–10, 14 | [GenSpawnLaws.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/laws/shared/src/main/scala/cats/effect/laws/GenSpawnLaws.scala#L23): `fiberJoinIsGuaranteeCase`, `uncancelableStartIsCancelable`, `raceCanceledIdentityLeft` | Review join/finalization, child mask independence, and race cancellation together. Reusable Scala effects and outcomes cannot be substituted for consuming Mojo recipes without an admission/ownership analysis. |
| 8–11, 14 | [TestControl.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/testkit/shared/src/main/scala/cats/effect/testkit/TestControl.scala#L123): `results`, `tickOne`, `advance`, `tickAll`, `seed`, `isDeadlocked`; [TestContext.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel-testkit/shared/src/main/scala/cats/effect/kernel/testkit/TestContext.scala#L62): `schedule`, `tickOne`, `advance` | Reproduce time and event interleavings through the real engine. Upstream randomizes some task ordering and its deadlock observation also covers external-scheduler waits; preserve our FIFO promises and distinguish quiescence from proven deadlock. |

### Local owners and starting checks

Paths below are repository-relative and identify existing owners to extend.
Do not create parallel implementations of these mechanisms while following
upstream examples.

| Passes | Start in this repository | Existing checks to extend |
|---|---|---|
| 7–8 | `src/fp/effects/_async/composition.mojo` (`Bind`, `Loop`), `kernel.mojo` (`_Slot`, `_tick`), `family.mojo`; native adapters in `src/fp/callables/` | `depth`, `loop_lifecycle`, `checkpoints`, `public_generic` |
| 7a–9 | `src/fp/_internal/erased.mojo` (`_Erased`), `src/fp/effects/_async/erased.mojo` (`_ErasedMachine`) | `erased_storage`, `erased_depth`; probes under `experiments/async-state-machines/probes/` |
| 7–9, 12 | `src/fp/_internal/waking.mojo` (`_Runtime`, `Signal`, registrations), `src/fp/effects/_async/host.mojo` (`Driver`, `Clock`), `children.mojo`, `nurseries.mojo` | `host_admission`, `scheduler`, `children`, `nurseries`, `instant_clock`, `instant_timers` |
| 9–11 | `src/fp/effects/outcomes.mojo`, `finalization.mojo`, `protocols.mojo`, `capabilities.mojo`, `coordination.mojo`; resumable owners under `src/fp/effects/_async/` | `async_masking`, `async_finalization`, `selection_policies`, `async_coordination`, `public_generic` |
| 12 | `src/fp/effects/_async/callbacks.mojo` (`Completion`, `Callback`), `host.mojo` (`Driver`, `TestControl`), `kernel.mojo` (`run`), the same wake registry, and `src/fp/effects/fibers.mojo` (`unsafe_start`, the OS-thread owner to share) | `callbacks`, `callback_origins`, `instant_cleanup`, `io_stepping`, `test_control`, `test_coordination` |
| 13 | `src/fp/effects/_async/engine.mojo` (`_RunLoop`, the fiber host), `fibers.mojo` (`_Fibers`, `_Inbox`, records and claims), `supervisor.mojo`, and `src/fp/_internal/waking.mojo` | `fiber_basics`, `fiber_drain`, `fiber_race_pair`, `fiber_supervisor`, `spawn_laws`, and the stress harness |
| 14 | `experiments/async-state-machines/qualify.py` and `stress.py`; `scripts/fp_tools/cases.py` (`CompileCase`, `execute_case`, `audit_case`) and `runs.py` (`RunContext`) | Extend existing inventories and auditors; keep overnight runs separately scheduled. |

Check names refer to clients under `experiments/async-state-machines/tests/`.
The [composition qualification example](async-composition.md#qualification-and-limits)
shows selecting clients with `--client`. For each pass, record which upstream
behavior was adapted, which native owner implements it, and the targeted
evidence supporting the contract. Update this map if local ownership moves;
keep pinned upstream references stable unless deliberately re-audited.

## Qualification and acceptance

Reuse the canonical command runner and evidence auditors. Short deterministic
checks precede broader matrices; overnight stress is scheduled separately.

- **Stack behavior:** runtime-built left-associated and deferred right-associated
  chains; heterogeneous intermediate values; target at least one million
  logical binds with a 1 MiB native stack. Exercise success, recovery, deep
  cleanup, suspension, cancellation, and disposal of unopened programs. Combine
  measurements with a review that every runtime-owned transition and destruction
  path is iterative; a finite depth test alone cannot prove the guarantee.
- **Construction and compilation:** distinguish runtime program depth from
  static type depth. A runtime loop building a chain should not instantiate a
  new nested type per iteration. Report compile time and memory separately.
- **Fiber lifecycle:** start/cancel handoff races, join-before/after-completion,
  canceled joiners, dropped observers, root exit with live children, child
  failures, masked cleanup, direct self-waits, and stale generation rejection.
  Verify heterogeneous child programs and exact move-only destruction counts.
- **Scheduling budgets:** verify cancellation checkpoints and yields using
  actual transitions across differently shaped effect trees. Include nested
  unwinding, masked cleanup, due timers, and maintenance work. Keep user-code
  execution costs distinct from interpreter work and quantify both.
- **Host services and publication:** cover owned versus borrowed services,
  partial initialization failure, shutdown with pending producers, and wakes
  before registration, during parking, and after retirement. Check interrupted
  waits, earlier deadlines, and partially drained event batches. Synchronization
  tests apply to every advertised shared-state profile; a single-thread run is
  not evidence for cross-thread publication.
- **Diagnostics and replay:** snapshot parked, runnable, canceled, and cleaning
  fibers; verify bounded storage and no payload retention. Reproduce controlled
  event schedules with recorded configuration and seeds/choices, including
  canceled joiners and cleanup suspension. Preserve FIFO guarantees and
  distinguish waiting for external input from completion. Keep these tests on
  the canonical engine and audit their retained evidence.
- **Laws and generic clients:** ordinary error/recovery laws, cancellation masks,
  spawn/join/cancel, time, and callback contracts. Compare outcomes and declared
  observable events under controlled schedules; do not equate differing
  scheduler step counts. Include a provider that lacks capabilities to verify
  precise rejection and independent-origin clients to detect hidden erasure.
- **Storage and performance:** separate live frames from retained results and
  observers. Repeated completed work should not retain the entire execution
  history. Measure allocations, maximum native stack, runnable/idle overhead,
  cancellation latency in scheduler transitions, and compile cost. Establish
  baselines before setting numeric budgets; no JVM/native speed-parity claim.
  If pooling is justified, compare it with that baseline and verify prompt
  frame reclamation in long-lived roots, exact destructor counts, alignment,
  origin preservation, and isolation from retained diagnostic/observer handles.
- **External work:** duplicate/late completion, registration failure, withdrawal
  failure, producer lifetime, publication ordering, and shutdown with in-flight
  work. Cross-thread tests apply only to an explicitly supported provider.

The new stack-safety claim is released only after the representation and all
runtime-owned unwind paths satisfy it. If a native representation cannot meet
the contract, preserve the existing preview and present the failing witness and
remaining alternatives. Do not relabel a deeper fixed-depth test or
`tail_rec_m` alone as general `flat_map` stack safety.

## Decisions and open questions

Approved: construction-paired private erasure; an owned-state precondition for
erased programs; fibers with stack safety before generic capability
dictionaries; and a public API in Cats Effect vocabulary around one `IO[T, E]`
type, replacing the typed recipe surface and keeping the runtime representation
private. Also retained: iterative execution and disposal, single-thread
lightweight fibers first, owner-held running work with a consuming result join,
and native outcome-preserving capabilities. Transition budgets, fiber
diagnostics, and controllable test scheduling accompany their runtime passes.
Host-service ownership, an `ExecutionContext` contract, and execution profiles
are specified before Pass 12. Since 2026-10-31, POSIX interfaces may be called
directly where the standard library lacks a facility, a multi-threaded
work-stealing runtime is Pass 13, and real platform providers remain separately
qualified, Linux first; allocation pooling follows evidence. The [Pass 7b review decisions](#review-decisions)
settle failure reporting, removal of the recipe names, and naming. Concurrent collection
operations remain deferred throughout.
