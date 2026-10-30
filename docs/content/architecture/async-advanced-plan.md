# Advanced IO and async development plan

Status: **proposal for discussion; implementation has not started**. This plan
continues the completed foundation passes 1–6 from `nightly` commit
`bda929c9bca31ed1b2311b191c9764eaac980f58`. It proposes lightweight fibers,
stack-safe general sequencing, and generic effect capabilities. Current support
remains defined by the [async guide](../guides/async-runtime.md).

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

All implementation remains pure Mojo, using supported native mechanisms. No C
backend, direct FFI integration, compiler coroutine dependency, compiler patch,
or standard-library modification is planned. Operations keep snake_case names.
The first fiber implementation remains cooperative on one host thread;
lightweight fibers do not require one OS thread per fiber or multicore execution.

GPU work, concurrent collections, and a wholesale port of the Cats Effect
standard library are outside this plan. Execution-context and external-completion
support are a later, separately qualified stage of capability coverage.

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

Pass 7 compares two library representations before committing to either:

| Candidate | Benefit | Required proof or limitation |
|---|---|---|
| Native heterogeneous storage behind a stable result/error/origin boundary | Supports runtime-built composition and different child program types through one scheduler | Demonstrate native storage, invocation, destruction, and origin retention; a trait existential is not assumed to be storable or sufficient. |
| Typed frames with an explicit closed set of alternatives | Keeps every payload and continuation concrete | Show how the program's admitted alternatives are represented; a fixed closed set alone does not establish general open-ended composition. |

Inspect existing native containers, callable adapters, ADT owners, and execution
slots before introducing storage. No unchecked cast to an erased value, widened
origin, invented Send/Sync proof, or copied move-only payload is an acceptable
shortcut. Compiler rejection of one candidate requires examining the other;
it does not by itself justify declaring the goal impossible.

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
| `cancel` | Request cancellation and suspend until termination and cleanup. Do not consume the child's result; retained failures remain available to join or scope settlement. |
| `cede` | Yield a runnable fiber so other eligible fibers can progress. |
| `never` | Remain pending until cancellation can be observed. |
| `race_pair` | Return the selected outcome and the other child's handle, transferring observation rights while the owning scope still retains execution ownership. Specify cancellation-only selection and parent-cancellation cleanup before exposure. |

The proposed ownership rules are:

1. The root or explicit owning scope owns entered execution. A handle grants
   observation/cancellation rights; dropping it cannot abandon a running child
   or invoke an asynchronous destructor. Scope closure closes admission, cancels
   remaining children, and drains them. Explicit joins allow normal completion
   before scope exit. Existing nursery normal-close semantics stay unchanged.
2. Success values and errors may be move-only. `join` cannot return the same
   owned result repeatedly or to several callers. Separate completion observers
   may share terminal status without duplicating the payload. Repeated result
   reads would require an explicitly constrained copying or sharing API.
3. Canceling a suspended joiner does not destroy its child. If the join right
   was consumed into that canceled join, result accounting returns to the owning
   scope. Parent-scope cancellation still cancels all its children.
4. Child failure is observed through join or scope settlement, rather than
   automatically failing every sibling. Existing `both` and nursery fail-fast
   policies remain explicit consumers of the same lifecycle. A joined failure
   is transferred once; an unobserved failure must reach scope settlement once.
   Cancellation-only shutdown is not fabricated into an error.
5. Completion, join publication, parent cancellation, and result observation
   have defined ordering. If cancellation prevents delivery after a result was
   removed from shared storage, transfer its failure accounting back to the
   scope and destroy any suppressed success exactly once. Do not lose errors
   or report a joined error twice.
6. Captured origins must outlive the owning execution scope. A fresh per-poll
   resource loan cannot escape into a background child. Independent external
   captures retain their origins, and resource owners cannot release while a
   child still has authorized access.
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

Pass 7 must specify an ordinary recoverable error channel separately from the
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

The first async provider stays on one host thread. Execution-context, blocking,
interruptible, and foreign-thread capabilities are added only with a supported
pure-Mojo provider and an explicit transfer/synchronization contract. Reusing
the old unsafe OS-thread backend does not establish safe payload transfer.
Native capability research is library work; compiler or stdlib changes are not
deliverables. If a provider is unavailable, preserve the usable narrower profile
and report the precise outstanding capability instead of declaring full parity.

## Runtime services, scheduling, and observability

These additions strengthen the same execution architecture. They do not add
concurrent collection operations or require a second runtime.

### Embedding and host-service ownership

Define host-service contracts during Pass 7, before adding platform providers
in Pass 12. An application should be able to supply scheduling and time services
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

Use controlled test providers before integrating a real platform poller. Replace
the current idle-sleep fallback only when a supported pure-Mojo provider can
meet this contract; no direct epoll/kqueue FFI implementation is authorized by
this architectural reference.

### Cancellation checks and yielding budgets

In Pass 8, account for actual interpreter transitions instead of treating a root
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
separate contracts. Define a profile matrix in Pass 7: thread-confined
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
or segmented storage only after Pass 8 establishes a correct implementation and
allocation baseline. Reuse canonical allocation and slot owners rather than
introducing an independent lifetime mechanism.

Keep per-frame retirement: a single root-wide arena must not retain all
completed work until a long-lived root exits. Separate execution storage from
retained results and observer metadata so a small surviving handle does not
pin an entire completed program. Reuse storage only after native payload
destruction and release of outstanding access rights; preserve alignment,
origins, generation protection, and exactly-once destruction. Bulk memory
release is not a substitute for running destructors or draining external work.
Pass 13 records whether measured allocation cost justifies pooling and retains
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
sleeps. Develop these controls alongside Passes 8–11 and qualify them in Pass 13.

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
| **7 — Contracts and representation proofs** | Decide carrier storage, origins, join ownership, failure accounting, and capability laws. Specify host-service ownership, event-polling contracts, and execution profiles. Compare the two storage candidates with bounded native compile/run probes after plan approval. | A runnable heterogeneous bind/fiber-storage witness with move-only values/errors and independent origins; rejection witnesses for escape/double ownership; a concrete API migration proposal and service/profile matrix. No production migration before review. |
| **8 — Iterative sequencing and unwinding** | Implement deferred construction and the selected stable carrier; drive continuations, errors, masks, finalizers, and disposal through one iterative engine. Add transition accounting, separate cancellation/yield budgets, controllable test-host stepping, and an allocation baseline. Adapt existing recipes and extension leaves. | Runtime-built deep binds and recursive deferred programs satisfy the stack contract, including cancellation, failure, and unopened disposal; budget checks cover nested work and masked cleanup; existing lifecycle behavior remains qualified. |
| **9 — General lightweight fibers** | Add typed handles, start/join/cancel, completion observers, `cede`, `never`, dynamic scoped ownership, and bounded diagnostic snapshots. Generalize canonical task storage rather than wrapping the homogeneous nursery. | Heterogeneous children progress independently; joining parks; all shutdown paths drain; observed/unobserved errors settle once; sequential spawn/join churn reuses storage; diagnostic handles do not retain payloads or completed graphs. |
| **10 — Cancellation and spawn capabilities** | Add generic error/defer/cancellation/spawn contracts and provider forwarding; expose `race_pair` with settled ownership rules. Reuse them for existing higher-level operations where contracts match. | Generic clients use minimal capabilities across actual and test providers; law/admission checks pass; no duplicate masking, error, or child-draining policy. |
| **11 — Coordination and temporal capabilities** | Add generic Ref/Deferred access and time/sleep/timeout contracts over canonical owners. Specify unique identity and clock domains; extend controlled scheduling to event delivery and virtual time. Audit ownership-sensitive derived operations. | Reproducible manual-time and cancellation laws respecting promised event ordering; no polling loop masquerading as suspension; no async collection API additions. |
| **12 — Complete integration capabilities where supported** | Implement pure-Mojo host-service and external-completion providers, with explicit event-waiting, interruption, shutdown, and blocking/interruptible support boundaries. Separate completion notification from payload transfer and external synchronization. | Every advertised Sync/Async operation has a real provider and tests; owned/borrowed service teardown, wake-before-park, and supported publication contracts pass. Otherwise publish the narrower profile and exact blocked obligation. No C fallback or implicit thread-safety assertion. |
| **13 — Advanced preview qualification** | Publish the provider/semantic matrix, migration guidance, runnable examples, and retained evidence. Qualify controlled schedule replay and diagnostic overhead; compare lifecycle, storage, and performance with the foundation. Evaluate pooling only against the allocation baseline. | Source/package O0/O3 checks, public generic clients, ownership rejections, bounded-stack, responsiveness, replay, and storage checks pass; any pooling preserves prompt reclamation and exact destruction. Run a separately scheduled overnight qualification before making sustained-load claims. |

Pass 7 is the first implementation step after review. Its scope includes small
feasibility experiments, not an unreviewed public API migration. Passes 8–11
form the first useful advanced-runtime milestone. Pass 12 can remain incomplete
without blocking qualification of that explicitly narrower milestone; it must
not be counted complete merely because callback syntax exists.

Each implemented pass gets targeted validation, a commit and push to shared
`nightly`, and an updated status in this page. Fetch and integrate other agents'
work before pushing. Keep this as one living plan instead of creating separate
pass journals. Retire it or fold completed decisions into current architecture
documentation once the work is delivered.

## Implementation reference map

Use the following inspected snapshots, not moving branches:

- **Scala Native:** [`b961982edab83915bcbbda559117f0a89d2f3e10`](https://github.com/scala-native/scala-native/commit/b961982edab83915bcbbda559117f0a89d2f3e10),
  a development snapshot. Virtual-thread interfaces here are runtime internals,
  not a stable API or a requirement to implement stackful continuations.
- **Cats Effect:** [`de84c01f76b2f42fcee9d43aba66c82992add103`](https://github.com/typelevel/cats-effect/commit/de84c01f76b2f42fcee9d43aba66c82992add103),
  covering its shared effect interpreter, native platform setup, and test tools.

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
| 8 baseline, 13 evaluation | [Zone.scala](https://github.com/scala-native/scala-native/blob/b961982edab83915bcbbda559117f0a89d2f3e10/nativelib/src/main/scala/scala/scalanative/unsafe/Zone.scala#L13): `alloc`, `close`, `Zone.acquire` | Give allocations an explicit owner and scope. Its raw allocation model does not establish Mojo payload destruction, origins, or prompt per-frame reclamation; retain those obligations when evaluating typed pools. |

### Cats Effect interpreter and native-host references

| Passes | Source and entry points | Concrete lesson and adaptation boundary |
|---|---|---|
| 7–8 | [IO.scala: flatMap](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IO.scala#L469), [defer](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IO.scala#L1296), and [FlatMap node](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IO.scala#L2236) | Compare stable outer `IO[A]` typing with heterogeneous internal steps. Use this to identify the representation problem; Scala's inheritance/erased references are not a Mojo storage proof. |
| 8 | [IOFiber.scala: runLoop](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L210), [succeeded](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L1210), and [failed](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L1270) | Trace continuation push/pop and return to the run loop. Upstream also uses bounded recursive fast paths via `MaxStackDepth`; do not mistake every helper for a loop or copy its casts. Prove all our runtime-owned unwind and disposal paths independently. |
| 8 | [IORuntimeConfig.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/unsafe/IORuntimeConfig.scala#L22), together with `IOFiber.runLoop` | Inspect `cancelationCheckThreshold`, `autoYieldThreshold`, and their validation. Borrow separate policies and accounting; determine thresholds from our transition costs rather than copying numeric defaults. |
| 9–10 | [IOFiber.scala: cancel/join](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L197), [prepareFiberForCancelation](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L1132), and [done](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/IOFiber.scala#L1092) | Follow cancellation through suspended finalizers to completion publication and execution-state release. Upstream caches a reusable join outcome; our exclusive move-only result transfer and unobserved-error accounting require their own design. |
| 7, 12 | [IORuntimeBuilder.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/unsafe/IORuntimeBuilder.scala#L26): `setCompute`, `setBlocking`, `setScheduler`, `addShutdownHook`; [native IORuntimeCompanionPlatform.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/native/src/main/scala/cats/effect/unsafe/IORuntimeCompanionPlatform.scala#L30): `createWorkStealingComputeThreadPool`, `createDefaultPollingSystem`, `createDefaultBlockingExecutionContext` | Study service assembly and teardown ownership separately from effect evaluation. Pools, global setup, and platform bindings are reference implementations, not authorization to add FFI or thread-unsafe payload execution. |
| 7, 12 | [PollingSystem.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/jvm-native/src/main/scala/cats/effect/unsafe/PollingSystem.scala#L36): `makePoller`, `poll`, `processReadyEvents`, `needsPoll`, `interrupt`, `closePoller`, `PollResult` | Specify wait/interrupt/ready-batch lifecycle before choosing a provider. The interface alone does not prove a lost-wakeup-free handshake; qualify that protocol against our generation and revision owners. |
| 9, 13 | [FiberInfo.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/FiberInfo.scala#L21): `state`, `trace`, `pretty`; [FiberMonitorShared.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/core/shared/src/main/scala/cats/effect/unsafe/FiberMonitorShared.scala#L21): `toFiberInfo`, `printFibers` | Borrow diagnostic vocabulary and presentation. `FiberInfo` explicitly retains the underlying fiber: our bounded snapshots must copy permitted metadata without retaining its payloads or execution graph. |

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
| 7, 10, 13 | [MonadCancelLaws.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/laws/shared/src/main/scala/cats/effect/laws/MonadCancelLaws.scala#L24): `uncancelablePollIsIdentity`, `uncancelableFinalizers`, `canceledAssociatesLeftOverFlatMap` | Enumerate cancellation/masking equations before claiming an instance. Translate each into observable native outcomes and ownership events; record differences rather than weakening error/cancellation state to pass it. |
| 9–10, 13 | [GenSpawnLaws.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/laws/shared/src/main/scala/cats/effect/laws/GenSpawnLaws.scala#L23): `fiberJoinIsGuaranteeCase`, `uncancelableStartIsCancelable`, `raceCanceledIdentityLeft` | Review join/finalization, child mask independence, and race cancellation together. Reusable Scala effects and outcomes cannot be substituted for consuming Mojo recipes without an admission/ownership analysis. |
| 8–11, 13 | [TestControl.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/testkit/shared/src/main/scala/cats/effect/testkit/TestControl.scala#L123): `results`, `tickOne`, `advance`, `tickAll`, `seed`, `isDeadlocked`; [TestContext.scala](https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel-testkit/shared/src/main/scala/cats/effect/kernel/testkit/TestContext.scala#L62): `schedule`, `tickOne`, `advance` | Reproduce time and event interleavings through the real engine. Upstream randomizes some task ordering and its deadlock observation also covers external-scheduler waits; preserve our FIFO promises and distinguish quiescence from proven deadlock. |

### Local owners and starting checks

Paths below are repository-relative and identify existing owners to extend.
Do not create parallel implementations of these mechanisms while following
upstream examples.

| Passes | Start in this repository | Existing checks to extend |
|---|---|---|
| 7–8 | `src/fp/effects/_async/composition.mojo` (`Bind`, `Loop`), `kernel.mojo` (`_Slot`, `_tick`), `family.mojo`; native adapters in `src/fp/callables/` | `depth`, `loop_lifecycle`, `checkpoints`, `public_generic` |
| 7–9, 12 | `src/fp/_internal/waking.mojo` (`_Runtime`, `Signal`, registrations), `src/fp/effects/_async/host.mojo` (`Driver`, `Clock`), `children.mojo`, `nurseries.mojo` | `host_admission`, `scheduler`, `children`, `nurseries`, `instant_clock`, `instant_timers` |
| 9–11 | `src/fp/effects/outcomes.mojo`, `finalization.mojo`, `protocols.mojo`, `capabilities.mojo`, `coordination.mojo`; resumable owners under `src/fp/effects/_async/` | `async_masking`, `async_finalization`, `selection_policies`, `async_coordination`, `public_generic` |
| 12 | `src/fp/effects/_async/callbacks.mojo`, `host.mojo`, and the same wake registry | `callbacks`, `callback_origins`, `instant_cleanup` |
| 13 | `experiments/async-state-machines/qualify.py` and `stress.py`; `scripts/fp_tools/cases.py` (`CompileCase`, `execute_case`, `audit_case`) and `runs.py` (`RunContext`) | Extend existing inventories and auditors; keep overnight runs separately scheduled. |

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

## Decisions to review before implementation

The recommended decisions are a stable typed program boundary, iterative
execution/disposal, single-thread lightweight fibers first, scope-owned running
work with a consuming result join, and native outcome-preserving capabilities.
Host-service ownership and execution profiles are defined early; transition
budgets, fiber diagnostics, and controllable test scheduling accompany their
respective runtime passes. Real platform providers remain separately qualified,
and allocation pooling follows evidence rather than preceding a correct baseline.
The exact carrier/API migration and ordinary-error law mapping depend on the
Pass 7 evidence. Concurrent collection operations remain deferred throughout.
