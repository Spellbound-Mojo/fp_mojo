# Async composition and child ownership plan

**Status: accepted and implemented in the private experiment.** This preserves
the design and acceptance gates used for the work. See the
[implementation record](async-composition-implementation.md) for representation
choices and qualification results. The plan builds on the
[validated state-machine foundation](async-state-machines.md).

The objective is to compose useful asynchronous programs while preserving
concrete value/error types, captured origins, cooperative cancellation, and
completion of entered finalizers. Runtime code remains pure Mojo. Cats and
Cats Effect guide the semantics, with Mojo ownership determining the interfaces.

## Scope and proposed interfaces

Keep this work in `experiments/async-state-machines/` until its contracts and
qualification results are reviewed. Names below describe private interfaces,
not additions to the public API.

| Operation | Proposed shape | Result |
|---|---|---|
| Sequencing | `bind(program, next)`; `next` consumes the first success value and produces one concrete machine type | Machine yielding the next machine's value |
| Iteration | `loop(initial, step)`; a repeatable `step` consumes state and produces a machine yielding `ControlFlow[Result, State]` | Machine yielding the `Break` payload |
| Structured children | `both(left, right)`; two owned machines with the same exact error type | Machine yielding their ordered value tuple after both finish |
| Scoped children | `scoped_both(left, right)` over two scoped machines with the same input and error types | Scoped machine receiving a fresh resource borrow on every poll |

The child pair is the first structured task scope. It owns a statically known
pair, can be nested, and joins implicitly through its enclosing machine. There
are no escaping child handles or detached tasks in this milestone. General
dynamic spawning, heterogeneous task registries, callback registration, OS I/O
readiness, and a public asynchronous effect family follow separately.

## Reuse boundaries

| Concern | Existing owner | Planned use |
|---|---|---|
| Callable admission and receiver selection | `fp.callables.protocols`, `call_once`, `call_repeated` | Reuse for continuation and loop factories; do not introduce parallel callable traits |
| Native error admission and capture | `_ErrorCompatible`, `_capture`, owned/borrowed callable adapters | Admit the selected error type or `Never`; retain exact payloads |
| Loop decisions | `fp.data.ControlFlow`, `Continue`, `Break` | Reuse the existing state/result convention |
| Outcome, cancellation and cleanup policy | `fp.effects.outcomes`, `_settle`, `IOContext` | Keep one implementation of failure accumulation and cancellation marking |
| Running state, waits and terminal consumption | Prototype `Task`, `Wait`, `Signal` | Generalize these owners for composition and children |
| Resource lifetime | Prototype `Scope`, `ScopedMachine`, `CleanupMachine` | Keep the owner outside fresh per-poll borrows; drain child work before release |
| Qualification | `scripts/fp_tools` and the prototype runner | Extend the client inventory and retain the existing four-way matrix |

Existing `tail_rec_m` uses a synchronous dependent fold. Reuse its value model
and admission rules; a resumable interpreter needs different execution state.
Existing `Fiber` owns a POSIX thread and joins synchronously, so it is not the
execution primitive for this pure-Mojo cooperative runtime.

If outcome conversion or exit merging needs a new common helper, put it under
the canonical outcome owner and make existing consumers delegate to it. In
particular, generalize `_scope_failure` if sequencing needs the same failure
retagging. Do not duplicate the resource code's error-merging branches.

## Typed sequencing

For source machine `P` and continuation `F`, require `F.Arg == P.Value`, a
concrete machine `Q == F.Out`, and `Q.Error == P.Error`. The factory's native
error must be compatible with that selected error type. Invoke it through the
existing one-shot callable boundary, including the consuming receiver mode.

The node owns the source, continuation, and eventually the next machine. Its
phases are source execution, ownership handoff, next execution, and completion.

1. Poll the source until it completes. Forward its wait conditions faithfully.
2. On failure or cancellation, finish without invoking the continuation.
3. On success, retain the owned value and yield a runnable transition. Before
   invoking the continuation, check observable cancellation again.
4. Move the value into the continuation exactly once. Capture a construction
   error as the existing outcome. If a machine was constructed successfully,
   install its owner before the next cancellation checkpoint.
5. Yield before polling the new machine. An unentered next machine may be
   discarded on cancellation; entered work must resume until its cleanup ends.

Factories are synchronous, bounded constructors; they cannot suspend or start
unowned background work. Their output owns transferred data or borrows an
independently retained external owner. It cannot borrow a temporary input or
consumed factory receiver. Resource-dependent views continue to use the scoped
per-poll contract.

Use a single sequencing interpreter. A minimal ready-value machine and `map`
can be thin adapters over it if needed by the examples. Error recovery, widening
unrelated error types, and a general `Monad` instance are outside this milestone.

## Iterative loops and progress bounds

A loop owns one state value, one repeatable factory, and at most one active step
machine. For fixed `State`, `Result`, and error `E`, every factory call returns
the same concrete machine type whose value is `ControlFlow[Result, State]`.
State, results, factories, and error payloads may be move-only.

- Invoke the factory through `call_repeated`; reject consuming-only factories.
- Move state into the step. On `Continue`, reclaim the next state and yield
  before constructing another step. On `Break`, return its payload.
- A construction error, step error, or observed cancellation stops iteration.
  Cancellation of an active step drives that step through finalization first.
- Release completed step storage before starting the next iteration. Retained
  interpreter state must not grow with the iteration count.

Initially, each composition node performs at most one factory invocation or
one active-child poll per outer poll, with explicit runnable transitions between
stages. This makes immediate completions cooperative without a second execution
engine for batching. Batching can be considered after behavior is qualified.

The loop must use constant native call-stack space with respect to iteration
count. A statically nested bind tree can still use stack proportional to its
type depth. Test that depth separately and report the verified range; do not
claim arbitrary-depth heterogeneous sequencing is stack-safe. Runtime-sized
repetition uses `loop`, not a recursively growing bind type.

## Structured ownership and readiness

### One linear owner for running work

Keep the outer `Task` linear: it can be consumed successfully only after its
entire computation, including children and cleanup, has completed. A group
cannot report completion while either child remains active.

The current `Machine` contract is Deinitable, while `Task` is not. Do not try to
store a linear `Task` in an Optional requiring Deinitable, or make task handles
silently droppable to satisfy that container. The proposed representation is
one linear root containing private, typed execution slots for descendants.
Factor the existing task transition logic into this shared internal owner;
both the root wrapper and groups delegate to it.

An execution slot has no independent public lifetime or extraction operation.
Its Deinitable storage, if required by native containers, is an implementation
detail inside the linear root. Slot destruction is allowed only after completion
or before first entry. This is a trusted interpreter invariant, while the
compiler enforces the external task ownership and captured origins. It retains
the prototype's limitation that manually polling and dropping raw machines
bypasses the task contract. Qualify this representation before building children;
if it cannot preserve these invariants, revisit the representation rather than
using untracked pointers or implicit destructor-driven scheduling.

### Readiness across children

Generalize `Wait` to describe an owned finite union of wake conditions. A group
must be able to wait for either child's signal, earliest relevant deadline, or
observable cancellation. Descriptors retain signal/token handles and revision
snapshots, never pointers into movable child frames.

Cancellation readiness must use the appropriate child's token and mask, not
blindly reuse the parent's context. Once a parent request has been forwarded,
it must not make every draining poll runnable forever: pending masked cleanup
still waits for its signal or deadline. The group remains ready when an
uncanceled-to-canceled child transition needs delivery.

Use the same readiness evaluation for root and child slots. Keep the existing
host idle strategy for this milestone. A group rotates among ready children and
polls at most one child per group poll. It does not call a blocking `run` or
`join` from inside `poll`. Notification-before-parking protection must survive
composition of the wake descriptors.

### Child lifecycle and cancellation policy

Each child has its own cancellation token. Children start unmasked; the parent's
current mask controls observation and forwarding of the parent's cancellation
request. A child's own resource scopes still mask their acquisition and cleanup.
Sibling cancellation does not cancel the parent token directly.

| Event | Group behavior |
|---|---|
| Group canceled before entry | Enter neither child |
| Both children succeed | Return values in left/right order after both complete |
| A child ends with failure or cancellation | Request cancellation of unfinished siblings and drain them |
| Parent cancellation becomes observable | Request cancellation of all unfinished children and drain them |
| A child is already complete | Retain its outcome; never poll or cancel it retroactively |
| A sibling was never entered | Discard its unopened recipe without running finalizers |
| Cancellation repeats while draining | Keep the original terminal outcomes and continue cleanup exactly once |

Failure detection is cooperative: cancellation of siblings starts when the group
observes a terminal unsuccessful child outcome. A child's cleanup can delay that
observation. The group never waits for a noncooperating child by blocking the
scheduler; it remains pending. Completion can nevertheless wait indefinitely
for nonterminating masked cleanup.

### Outcomes and resources

Require a common exact error type for a group; its success types may differ.
Preserve every child failure, including failures produced during cancellation.
Errors dominate a cancellation-only outcome. Merge error lists in child
declaration order, retaining body/finalizer order within each child. For nested
groups this gives a deterministic left-to-right order rather than timing order.

Proposed cancellation meaning: an aggregated failure is marked canceled if the
parent observed cancellation or any child completed with cancellation,
including cancellation induced by a sibling's failure. Merely requesting
cancellation does not change an already completed outcome. This is an explicit
group policy, not a claim of complete Cats Effect compatibility.

Keep successful payloads owned while other children drain, then return or destroy
them once. Use `_ExitState` and generalize canonical exit merging if needed to
combine failures without copying move-only successes or errors. A surrounding
resource scope appends its cleanup failures after the group's failures using
the existing finalization policy.

For `Scope(acquire, scoped_both(left, right), cleanup)`, both child machines
receive fresh borrows during their individual polls. Neither may retain a borrow
into the movable scope. The outer resource remains alive until both children and
their entered cleanup have completed. The scoped invocation signature may need
its own adapter; running-state and outcome policy must stay shared.

## Implementation sequence and acceptance gates

| Phase | Deliverable | Gate before continuing |
|---|---|---|
| 0. Ownership representation | Shared private execution slots under the linear root; a minimal nested owner probe | Drop/escape rejections, movement while pending, and unchanged foundation behavior |
| 1. Sequencing | Typed bind, construction-error capture, minimal adapters | Exact ownership handoff; skipped factories on failure/cancellation; source and continuation cleanup |
| 2. Iteration | Fixed-type resumable loop | Long runs with bounded interpreter state, cancellation checkpoints, and progress of a sibling task |
| 3. Structured pair | Composed readiness, cancel-and-drain lifecycle, deterministic outcome aggregation | All child outcome combinations; parent cancellation at each lifecycle boundary; no lost wakeups |
| 4. Scoped composition | Scoped pair adapter and nested groups in resource bodies | Resource survives child cleanup; nested cancellation drains all descendants before release |
| 5. Qualification | Updated architecture record and retained evidence bundle | O0/O3, source/package routes, warning-free precompilation, expected rejection diagnostics, docs checks |

Keep each phase independently reviewable. Changes to canonical internal helpers
also run the existing affected callable/outcome/resource tests. Extend the
experiment runner's explicit positive-client inventory and expected output files;
it currently recognizes only the original foundation client.

The acceptance suite must cover these behaviors:

- **Sequencing:** differing input/output types; consuming factories; move-only
  results and errors; external borrowed results/errors; factory failure; a
  cancellation request between success and factory entry; cancellation after
  next-machine entry; representative nested bind depths including 64.
- **Iteration:** at least one million immediate iterations; suspending steps;
  move-only state; `Break` without an extra invocation; failure/cancellation
  without another iteration; a ready sibling making progress; constant active
  step count and bounded retained interpreter storage, independent of payload
  allocations. Test stack
  behavior under a recorded bounded stack budget, separately from type depth.
- **Children:** the four terminal states success, error, cancellation, and
  error-plus-cancellation on each side; both observation orders; repeated parent
  cancellation; error during sibling cleanup; unopened siblings; independent
  child tokens; deterministic error order and exactly-once outcome consumption.
- **Waiting and scope exit:** two distinct signals, mixed timers/signals,
  notification before parking, masked cleanup after parent cancellation, and
  movement of the group while pending. Nested scopes must release resources
  only after all relevant descendants finish.
- **Compile-time boundaries:** wrong continuation input/error types, a
  consuming-only loop factory, incompatible loop state, task abandonment,
  captured-owner escape, and retained or returned per-poll resource borrows.
  Pair negative fixtures with close valid controls.

Drive race cases with controlled poll steps and explicit signals, not timing
guesses. Keep real-clock tests limited to deadline behavior. A bounded manual
driver can assert that deliberately blocked cleanup remains pending without
hanging the test process. Every gate retains timeouts and counts crashes or
unexpected rejection acceptance as failures.

## Completion and later decisions

This milestone is complete when a resource body can run a typed child pair,
with each child sequencing and looping, and parent cancellation drains the
whole entered subtree before releasing the resource. The example must retain
exact failures and native origins through both source and package imports.

The implementation retains the child cancellation and error-order policy, the
trusted internal-slot boundary, and the distinction between static bind depth
and runtime iteration count. Representation changes and qualification limits
are recorded separately. Public exports, dynamic spawning, arbitrary-depth
sequencing, and replacing the idle scan require later designs and evidence.
