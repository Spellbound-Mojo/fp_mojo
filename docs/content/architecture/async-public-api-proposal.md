# Proposed public async API

This proposal defines a first public surface for the pure-Mojo runtime already
implemented under `experiments/async-state-machines/`. It follows the
[readiness review](async-public-api-review.md). **Status: proposed for review;
the imports and additions below are not available public APIs yet.** This page
changes no runtime behavior or exports.

The recommended contract is cooperative execution on one host thread, concrete
owned machine types, exact typed outcomes, and structured cleanup. Cats and Cats
Effect inform sequencing, resources, and cancellation; native Mojo ownership and
origins determine the representation. Long-running stress and performance work
is deferred to a later overnight pass. It is not needed to discuss this design.

## Cats alignment and naming

The foundation broadly aligns with Cats Effect: lazy work, typed sequencing,
structured child ownership, cancellation masks, and finalizers that finish before
their owner returns. The initial proposal exposed too much of the machine layer
and deferred too much of the everyday application API. This revision makes
`Async[E]` integration with the existing `Pipeline`, compositional resources, and
explicit error recovery requirements for the first application preview.

All public functions, methods, modules, and parameters use **snake_case**:
`flat_map`, `tail_rec_m`, `handle_error_with`, `guarantee_case`, `on_cancel`,
`timeout_to`, and `with_permit`. There are no camelCase method aliases. Type and
trait names retain the repository's conventional Mojo/Python class spelling,
such as `AsyncResource`, `EffectFailure`, and `Driver`. Scala familiarity comes
from composition and behavior, without emulating Scala syntax or implicits.

| Cats / Cats Effect concept | Recommended Mojo surface | Alignment or deliberate difference |
|---|---|---|
| `map`, `flatMap`, `*>`, `<*` | Existing `Pipeline` with `.map`, `.flat_map`, `.product_r`, `.product_l` | Sequential composition through the native async family |
| `tailRecM` | Existing `tail_rec_m[Async[E]](step, initial)` | Iterative execution; native `ControlFlow` replaces the iteration `Either` |
| `Resource.make(...).flatMap(...).use(...)` | `resource(...).flat_map(...).use(...)` | Same lifecycle intent; fresh scoped loans preserve native ownership |
| `attempt`, `handleErrorWith` | `attempt`, `handle_error_with` | Handle the complete typed failure; cancellation remains terminal |
| `race`, `timeoutTo` | `race`, `timeout_to`, subject to the policy gates below | Current experimental result selection is different and must not silently take these names |
| `Fiber.cancel` | Host `Driver.request_cancel()` followed by polling and `finish()` | Requesting cancellation alone does not join |
| `Async.async` | `callback(register, withdrawal)` | Withdrawal always runs after entered registration, including success |
| `Outcome` | Canonical `Outcome[T, E]` | Owns success directly and preserves all errors plus a cancellation flag |
| `Semaphore`, bounded `Queue` | Existing coordination owners | No waiter fairness guarantee; queue capacity must be positive |

This is conceptual alignment, not Cats Effect compatibility or a claim to
implement its full typeclass hierarchy. The comparisons use the repository's
pinned [Cats FlatMap][cats-flat-map] and [ApplicativeError][cats-errors] sources,
and Cats Effect [GenSpawn][ce-spawn], [GenTemporal][ce-temporal],
[MonadCancel][ce-cancel], [Async][ce-async], [Resource][ce-resource],
[Outcome][ce-outcome], [Semaphore][ce-semaphore], and [Queue][ce-queue]. They do
not assume that every release has identical behavior.

## Namespace and supported boundaries

Use `fp.effects.async_runtime` for application construction and host execution.
Use `fp.effects.async_runtime.protocols` for implementing custom leaf machines
and scoped bodies. Both are documented import paths. Other submodules are
implementation details. Examples should qualify the application module as `ar`
when synchronous operations are also in scope.

Keep canonical `Outcome`, `EffectFailure`, `ExitCase`, `CancellationToken`, and
`Permit` in `fp.effects`; `ControlFlow`, `Continue`, `Break`, `Left`, and `Right`
remain in `fp.data`. Async operations use these exact types. Do not introduce a
second outcome representation or re-export conflicting async names from
`fp.effects` itself.

The first surface has three boundaries:

| Boundary | Supported names | Purpose |
|---|---|---|
| Application | `Async[E]`, `AsyncResource`, constructors and coordination handles below; `RaceResult`, `Poll`, `Duration` | Build unopened, concretely typed work; compose with existing `Pipeline` |
| Host | `Driver`, `Progress`, `Clock`, `run` | Own execution, deliver events, observe deadlines, and drain shutdown |
| Extension, from `.protocols` | `Machine`, `ScopedMachine`, `CleanupMachine`, `Step`, `Wait`, `Signal`, `Context` | Implement cooperative leaf operations and bodies with per-poll loans |

`Context[E]` is a public alias of canonical `IOContext[E]`. Add `now() -> Int`
to that canonical context so extensions can read the inherited clock without
accessing `_clock`. The existing `canceled()` and `request_cancel()` retain
their meanings. Tokens, mask markers, parent registrations, slots, subscriptions,
locks, and scheduler storage stay outside the extension contract.

Raw `Task`, `run_pair`, detached start/join handles, cross-thread callback delivery,
OS readiness registration, and custom child schedulers are outside this first
surface. `Driver` is the single application root owner. Library combinators own
child execution; custom leaf machines do not manually poll nested recipes.

## Room for heterogeneous execution

The explicit state-machine model has no identified fundamental conflict with
host-side orchestration of GPU or other accelerator work. The current runtime
executes on the host; running its scheduler inside device kernels is a separate
problem. This is an architectural assessment, not qualified GPU support.

Preserve the following general contracts while developing the application API:

- **Keep scheduling independent of the work's execution location.** A leaf can
  represent externally executing work. Device identity, streams, dependencies,
  and address-space-specific values belong to concrete adapters and their owned
  resources. They do not require device fields in `Context` or vendor-specific
  variants in `Wait`. `both` schedules children without choosing their devices
  or promising parallel execution on a particular stream.
- **Distinguish submission from completion.** Returning from a submission call
  does not establish that external work has finished. An operation promising
  completed work must observe that completion and discharge its cleanup before
  becoming terminal. Retain buffers, access rights, and required handles until
  outstanding uses finish; a fresh per-poll loan alone cannot authorize access
  after the poll returns. Readiness notifications do not replace device memory
  synchronization or establish that host access is safe.
- **Treat cancellation as a request with draining obligations.** Do not require
  every operation to be immediately interruptible. Stop further submissions
  where possible and drain already submitted work before releasing its resources.
  Cancellation and timeouts do not imply that external execution has stopped.
  Completion and cleanup failures still use the canonical typed outcome policy.
- **Keep external completion behind the host boundary.** Future adapters should
  feed the existing signal/completion mechanisms through an appropriate host
  integration. The first preview's one-host-thread restriction remains in force;
  copyable handles and movable recipes do not establish cross-thread safety or
  permission to migrate execution. A future foreign-thread notification bridge
  needs its own contract. Ordinary polls must continue returning cooperatively
  instead of blocking the scheduler while external work runs.
- **Allow batching within an owned operation.** The API must not require one
  runtime task or a host round trip for every kernel or transfer. A future leaf
  may own a batch and its dependencies while exposing one completion boundary.

These are clarifications of the existing ownership, host, and cleanup boundaries.
GPU APIs, backend traits, completion bridges, kernel execution, and GPU tests
remain outside the present work and are not prerequisites for the application
preview. No speculative device abstraction or custom C backend is added.

## Recipe and callable contract

In the tables, `M[T, E]` means any concrete `Machine` with `Value == T` and
`Error == E`. It is signature notation, not a proposed erased type or a Mojo
declaration. `T`, `E`, state, and callback types retain their native origins.

Constructors consume recipe and callback arguments. Construction invokes no
user callback. `pure` owns an already evaluated value; `delay` postpones the
callback that produces it. Unopened recipes can be discarded. Once driven,
the root owner must remain alive until execution and cleanup finish. Recipes
are consumed for one execution; repeating work constructs another recipe with
a factory. This differs from reusing a Scala `IO` description and permits
move-only values and captures without implicit cloning or memoization.

Select `E` explicitly for leaf operations such as `pure[E]`, `delay[E]`, and
`sleep[E]`; composites infer it. A continuation's machine must have exactly the
source error type. A native callback can raise that `E` or `Never`; there is no
implicit error union or conversion to `Error`. Multiple error kinds require a
caller-selected native sum type shared by the computation.

Ordinary native functions, stored thin functions, closures, and library callables
should be admitted through the existing callable adapters and invocation owners.
One-shot continuations can consume captures. Loop factories must be repeatable
and cannot consume their captures once per iteration. Admission borrows end at
construction; independently borrowed captures must outlive execution. This native
callback convenience is an addition to the experiment's protocol-callable entry
points and needs focused qualification before publication.

## Construction and sequencing

| Proposed call shape | Result | Contract and implementation owner |
|---|---|---|
| `pure[E](value: T)` | `M[T, E]` | Move the value into the existing `Pure` recipe |
| `delay[E](thunk)` | `M[thunk.Out, E]` | New adapter; defer one synchronous callback, using canonical IO delay and execution |
| `eval_io(program)` | `M[program.Value, IOContract[program].Error]` | New bridge; consume a compatible synchronous IO recipe in one poll, using the current context |
| `pipeline(program).map(function)` | Pipeline containing `M[B, E]` | Use existing family dispatch; move the success into the callback and capture its compatible error |
| `pipeline(program).flat_map(next)` | Pipeline containing `M[B, E]` | Invoke `next` once after success to obtain `M[B, E]`; delegate execution to `Bind` |
| `pipeline(program).product_r(next)` / `.product_l(next)` | Pipeline retaining the selected side's value | Sequential execution; an unsuccessful left side skips the right side |
| `tail_rec_m[Async[E]](step, initial: S)` | `M[B, E]` | Each call consumes `S` and returns the same concrete machine type yielding `ControlFlow[B, S]`; execute through `Loop` |
| `sleep[E](duration: Duration)` | `M[NoneType, E]` | Function spelling over `Sleep[E]` with checked duration; deadline starts on entry |

`pipeline` and `tail_rec_m` keep their existing public import paths. Generic
free algebra functions keep the repository's callback-first convention; this
proposal does not add a competing value-first `flat_map` overload. The
experimental `bind(program, next)` and `loop(initial, step)` identify execution
owners, rather than the main application vocabulary. Existing Pipeline `.get()`
supplies the concrete machine to `Driver` or other constructors without running it.

`Continue[S]` moves the next state; `Break[B]` moves the final value. Looping
retains one current step and yields between iterations. This supports constant
active iteration state and stack use; it is not a blanket stack-safety or
compilation-cost promise for arbitrary recursively nested concrete bind types.

`delay` and `eval_io` are synchronous inside their poll. They do not make blocking
IO asynchronous, offload it to a thread, or preempt a long callback. Use them for
short work and use `callback` for externally completed operations. The IO bridge
must invoke the canonical runner with the current context, preserving its clock,
mask, token, and scheduler ancestry; calling top-level `run_io` with a fresh
context would violate this contract.

Construction has no native callback error. Callback failures enter the canonical
`Outcome` during execution. Family mapping delegates to the existing bind and
callable mechanisms; it does not add a second execution state machine.

## Error recovery

Familiar error operations belong in the application preview, with a contract
that accounts for aggregated errors and cancellation. In this signature
notation, the proposed async entry points are:

| Proposed call shape | Result | Policy |
|---|---|---|
| `raise_error[E, T](error: E)` | `M[T, E]` | Create a deferred failure containing one domain error |
| `attempt(program: M[T, E])` | `M[Result[T, EffectFailure[E]], E]` | Turn success or a noncanceled failure into a value; preserve cancellation as terminal |
| `handle_error_with(program: M[T, E], handler)` | `M[T, E]` | Transfer the complete noncanceled `EffectFailure[E]` to a once-callable returning `M[T, E]` |

Cancellation-only outcomes and failures whose cancellation flag is set bypass
recovery. They retain every stored error. `attempt` therefore retains `E` in
its outer machine type: a combined error-and-cancellation outcome can still be
terminal. Once a handler takes ownership of a failure, it decides what to retain;
a handler failure replaces the handled failure rather than implicitly copying
or reattaching it. A later parent cancellation still applies to the result.

These operations must reuse the canonical outcome and error owners, and their
Pipeline forms must use existing dispatch. The core `Async[E]` family initially
targets Functor/Monad. Do not assert a lawful `ApplicativeError` instance merely
by setting its `Failure` to `EffectFailure[E]`: a value with its cancellation
flag set would undermine the usual raise/handle laws. The recovery capability,
relationship to the existing `fail` operation, and native signatures must be
qualified before these names are exported. No second failure representation or
separate recovery interpreter is proposed.

## Structured concurrency and timeouts

| Proposed call shape | Successful value | Terminal policy |
|---|---|---|
| `both(left: M[A, E], right: M[B, E])` | `Tuple[A, B]` | Both succeed, or failure/cancellation requests sibling cancellation and drains both |
| `race_first(left: M[A, E], right: M[B, E])` | `RaceResult[A, B]` | Preserve the experimental first-terminal policy; cancel and drain the loser before returning |
| `race(left: M[A, E], right: M[B, E])` | `RaceResult[A, B]` | Proposed cancellation-aware selection described below; requires a behavior change |
| `timeout_after(program: M[T, E], duration, fallback: M[T, E])` | `T` | Preserve the experimental timer-selection policy; after timer victory and clean draining, select fallback |
| `timeout_to(program: M[T, E], duration, fallback: M[T, E])` | `T` | Proposed source-outcome preference after cancellation and draining; requires a behavior change |
| `Nursery[P](limit)` | Its recipe yields `List[P.Value]` | Own at most `limit` total accepted children of one exact machine type |

`RaceResult[A, B]` remains the canonical `Choice` with `Left[A]` and `Right[B]`.
Equal arm types remain distinguishable. The proposed names `race_first` and
`timeout_after` make the existing policies explicit; neither is an existing
export under that spelling. `race_first` selects the first observed terminal
outcome, including cancellation. It discards losing success, normalizes losing
cancellation, and retains losing errors. It is not Cats Effect `raceOutcome`,
which returns the selected outcome as data.

For the proposed `race`, a first success or error selects that side. If the first
outcome is cancellation-only, cancel and drain the other side, then use its
success or error if available; cancel if both sides cancel. This follows the
selection in the pinned [Cats Effect implementation][ce-spawn], which explicitly
cancels and joins the other fiber even in the first-cancellation branch. It is
not a first-success race. Mojo continues to retain all errors, including losing
cleanup errors; those can turn a selected success into failure. A mixed
error-and-cancellation outcome retains its cancellation flag, and parent
cancellation is settled independently. These are explicit deviations from
Cats Effect's exclusive outcome cases.

For the proposed `timeout_to`, timer victory requests cancellation and drains
the source. A surviving source success or failure determines the result;
fallback runs only after cancellation-only completion. In particular,
uncancelable source work may succeed after the timer fires and suppress fallback,
as in [Cats Effect][ce-temporal]. With `timeout_after`, timer victory instead
discards source success and selects fallback after clean draining. Both operations
take a checked `Duration`; cleanup failure prevents fallback and parent
cancellation skips it. Neither imposes a hard deadline on return: masked work
and finalizers can delay completion indefinitely.

These are publication gates, not changes made by this document. Today, canonical
cancellation settlement can discard a success before the race or timeout wrapper
sees it. Merely renaming the wrapper or changing its final branch cannot establish
the proposed result-selection contract. Review cancellation checkpoints and child
outcome ownership first, preserving one canonical settlement mechanism. Qualify
late success, first-child cancellation, masked work, simultaneous readiness,
losing cleanup failure, and parent cancellation with short deterministic tests.
Also specify masked cancellation-only composition: Cats Effect can remain
suspended when both raced fibers cancel under a mask; this proposal does not
claim that behavior from the current Mojo settlement rules.

Observation order remains deterministic: initial ties favor the left child
(the source for a timeout), and later selection follows scheduler readiness
order. There is no timestamp arbitration or guarantee that physically
simultaneous events are observed together. A zero duration permits an immediately
terminal source to win under this rule.

`Nursery[P].spawner()` returns a copyable `Spawner[P]`. Its immediate
`try_spawn(child)` consumes the recipe and returns `None` on acceptance or the
original unopened recipe on rejection. `close()` is idempotent and ends admission;
normal closure lets accepted children finish. Failure or cancellation closes
admission and cancels unfinished children. Completion collects values and errors
in admission order. The host must arrange closure for a normally finishing nursery.

The limit covers queued, active, and completed children for the nursery's whole
execution. It is not replenished when a child finishes. An unlimited service can
use a fixed number of looping workers and a bounded queue. Heterogeneous admission
requires an explicit common native representation. Retained spawners reject work
after closure or nursery destruction and never own detached running tasks. This
finite admission scope is not an equivalent of Cats Effect `Supervisor` or a
reusable worker pool.

## Resources and finalization

| Proposed call shape | Contract |
|---|---|
| `resource(acquire, release)` | Construct an unopened `AsyncResource`; release borrows the resource through a scoped cleanup recipe |
| `resource_case(acquire, release)` | As above, with exact `ExitCase[E]` available during cleanup |
| `resource_recipe.map(function)` | Transform a borrowed resource value while retaining its release ownership |
| `resource_recipe.flat_map(next)` | Acquire a dependent resource; retain both owners and release in reverse order |
| `resource_recipe.use(body)` | Consume the resource recipe into a machine; close all acquired resources on every terminal path |
| `scope(acquire, use, release)` | New function spelling over `Scope`; acquire `R`, lend `R` to a `ScopedMachine` per poll, then release through `CleanupMachine` |
| `scoped_both(left, right)` | Existing scoped pair; each child receives the same resource through a fresh immutable loan |
| `guarantee(program, cleanup)` | Run owned cleanup after entry on every terminal path; discard its successful value |
| `guarantee_case(program, cleanup)` | Cleanup is a `ScopedMachine` borrowing exact `ExitCase[E]` for each poll |
| `on_cancel(program, cleanup)` | Run cleanup when the body exit records cancellation, including failure plus cancellation |
| `uncancelable(program)` | Execute under a fresh lexical mask |
| `uncancelable_with[E](factory)` | Consume a once-callable factory taking `Poll[E]` and returning a machine with exact `E` |
| `poll.apply(program)` | Restore the cancellation state preceding that Poll's active lexical region |

All error types match exactly. Scope acquisition and cleanup are masked. A
failed acquisition does not release a nonexistent resource. Once acquisition
succeeds, cleanup runs even if cancellation skips the body's first poll. Scope
keeps the resource and any completed body value alive through suspended cleanup.
A partially acquiring operation must own and clean up its own partial state.

The compositional builder is part of the first application preview, following
the familiar [Resource lifecycle][ce-resource]. It must reuse or generalize the
existing resource descriptors and composition owners, with asynchronous lifetime
managed by `Scope`. The synchronous resource runner cannot simply be wrapped in
a poll to support suspended acquisition or cleanup. There must be one async
scope engine, not a separate interpreter hidden inside `AsyncResource`.

The guarantee constructors install their protection before body execution;
cancellation after that entry still finalizes. An entirely unopened recipe
executes no finalizer. Resource and exit loans use immutable origins and end when
each poll returns. Neither stored state nor results can retain those fresh loans;
independent external captures and returned origins remain valid. There is no
mutable-scoped contract in this proposal.

`use` admits a `ScopedMachine` for work that needs the resource across suspension.
A convenient native body factory may borrow the resource to construct an owned
machine, but that returned machine cannot retain the factory's fresh loan.
Likewise, `map` and `flat_map` callbacks cannot return values or recipes capturing
that fresh loan. Dependent operations that need continued access require scoped
descriptors that receive fresh loans while executing. The exact native signatures
and composition representation need qualification before publication; a familiar
method name is not permission to extend an origin or erase a type.

`guarantee_case` lends `ExitCase[E]`, including errors and cancellation, without
lending the successful payload. Cats Effect passes an `Outcome` whose success
contains an effect yielding that payload. This deliberate difference lets Mojo
retain a move-only successful value through finalization without copying it.

`Poll` is copyable but restores only its matching current region. It cannot
pierce a newer mask, a finalizer's mask, or another child's independent region.
An escaped handle is inert outside its region. It preserves current task metadata
when restoring cancellation state. Children start with independent, initially
unmasked tokens; the parent's mask controls when its request reaches them.

These constructors continue sharing Scope, canonical exit/error accumulation,
and mask restoration. Cleanup errors remain in the terminal outcome alongside
body errors or cancellation. This differs from Cats Effect's suppression or
side-channel reporting of some finalizer errors, notably cancellation finalizers
and a failing `guaranteeCase` finalizer after a body error. Do not document the
two error policies as equivalent.

## Callbacks and coordination

`callback(register, withdrawal)` returns `M[T, E]`. Registration is a synchronous
once-callable accepting `Completion[T, E]` and returning `NoneType`; it can raise
`E` or `Never`. The already-owned withdrawal machine has value `NoneType` and
exact error `E`. Registration can retain a copy of the completion handle.

`Completion.complete(outcome: Outcome[T, E]) -> Bool` consumes the supplied outcome.
The first accepted terminal decision closes the cell. Later calls return `False`
and destroy their input, including after task completion. Copies preserve native
origins; shared metadata ownership does not extend an external borrow's validity.
Withdrawal runs after every entered registration, including partial registration
failure and immediate completion, and can suspend under a mask. Calls to completion
and submission handles belong to the same host thread in this initial contract.

Selecting a completion outcome does not finish the enclosing callback recipe:
withdrawal must still drain any external use that it owns before the recipe can
become terminal. This preserves the external-work contract above without adding
a device-specific callback API.

This is a registration scope, not a spelling of [Cats Effect `async`][ce-async].
That API has effectful masked registration which returns an optional finalizer
for cancellation only; absence of that finalizer makes its wait uncancelable.
Here registration is synchronous, withdrawal is owned before registration, and
withdrawal also runs after successful completion. Completion accepts a full
canonical outcome, including cancellation, rather than only an error or value.

Coordination handles are copyable shared owners; their methods below return
unopened machines, not immediate values:

| Handle | Methods and successful values |
|---|---|
| `Deferred[T]`, with copyable `T` | `complete[E](value) -> Bool`; `try_get[E]() -> Optional[T]`; `get[E]() -> T` |
| `Queue[T](capacity)`, with movable `T` | `size[E]() -> Int`; `try_offer[E](value) -> Optional[T]`; `offer[E](value) -> NoneType`; `try_take[E]() -> Optional[T]`; `take[E]() -> T` |
| `Semaphore(permits)` | `available[E]() -> Int`; `acquire[E]() -> Permit`; `with_permit(program) -> program.Value` with the program's error type |

`Deferred.complete` reports whether assignment won. Readers receive copies.
Queue values are FIFO. A successful `try_offer` returns `None`; rejection returns
the original value. Waiting `offer` owns its value until enqueued or canceled.
The `try_` operations do not wait for capacity or an item, but can yield on guard
contention. No FIFO ordering among waiting producers, consumers, or permit
acquirers is promised.

In particular, [Cats Effect Semaphore][ce-semaphore] promises FIFO permit
acquisition; this runtime does not. [Cats Effect bounded Queue][ce-queue] also
supports a zero-capacity rendezvous queue, while this proposal requires positive
capacity. Its `tryOffer` reports a Boolean; Mojo `try_offer` returns a rejected
value to preserve move-only ownership. Handle construction allocates shared state
immediately here; use `delay` with a compatible error type when allocation must
be deferred into execution.
These differences must be visible in migration examples.

Cancellation does not roll back committed queue operations or callback side
effects. A removed value whose success is suppressed by late cancellation is
destroyed. `with_permit` acquires cancelably and retains the canonical owned
permit through body cleanup. Permits are returned through that existing owner.
These methods keep using the synchronous library's shared state transitions.

## Host contract and shutdown

`Driver(program)` creates a fresh token and monotonic clock.
`Driver(program, token, clock)` copies the supplied shared handles. Both consume
the unopened program into a movable, non-Deinitable root. The supported members
are `poll(budget)`, `request_cancel()`, and consuming `finish()`; internal task
and context fields are not public extension points.

| `Progress` field | Meaning |
|---|---|
| `completed: Bool` | The entire subtree, including owned external work and cleanup, is terminal |
| `runnable: Bool` | More work can be attempted immediately, including a due timer |
| `deadline: Optional[Int]` | Earliest live deadline in the supplied clock's nanoseconds |
| `polls: Int` | Root polls performed by this call |
| `timers: Int` | Timer events processed by this call |

`poll(budget)` performs at most `budget` root polls plus timer events. A root
poll can invoke nested operations; this is not a bound on all child polls,
instructions, wall time, destructor work, wake fanout, or heap maintenance.
Budget zero observes status without making progress. The driver itself performs
no host idle sleep. Callbacks and custom polls must cooperate by returning.

The host delivers available events, calls `poll`, and uses `runnable` and
`deadline` to choose its next call. When idle, the host arranges another call
after event delivery or the reported deadline. The runtime does not install an
OS event source or a host wake hook. If no source can complete parked work, the
host must request cancellation and continue draining.

`request_cancel()` requests cancellation; it does not join. This is the proposed
public spelling for the experiment's `Driver.cancel()`, so users do not infer
the joining contract of Cats Effect `Fiber.cancel`. The existing canonical
`CancellationToken.cancel()` API is unaffected. Continue polling until
`completed`, then call `finish()` exactly once to obtain
`Outcome[P.Value, P.Error]`. `finish()` before completion is a contract violation.
There is no abandon or detach operation, and automatic destruction cannot run
asynchronous cleanup. An uncooperative poll or nonterminating masked cleanup can
prevent shutdown. Moving a driver preserves all these obligations.

`run(program)` and `run(program, token)` are blocking convenience runners for
self-contained work. They use the same Driver with the existing 1 ms idle-sleep
fallback. Host-delivered callbacks normally use Driver directly.

`Clock()` reads monotonic nanoseconds. `Clock.manual(now=0)` creates shared
deterministic time; `advance_to(now)` only advances a manual clock. Absolute
deadlines use that clock's origin and are not wall-clock timestamps.

## Outcomes, invalid inputs, and extension rules

The terminal shape stays `Optional[Result[T, EffectFailure[E]]]`: outer absence
means cancellation, `Ok` means success, and `Err` holds a nonempty ordered error
collection plus an independent cancellation flag. Failure can coexist with
cancellation. Errors are never discarded merely because cancellation arrived.

Cats Effect's [Outcome][ce-outcome] has exclusive success, error, and cancellation
cases; its successful case contains `F[A]`. Our success owns `T` directly, and
mixed failure/cancellation is intentional. Propose a consuming
`fold_outcome(outcome, on_success, on_failure, on_cancel)` in the canonical
`fp.effects` outcome module: success transfers `T`, failure transfers the entire
`EffectFailure[E]` including its cancellation flag, and cancellation-only invokes
`on_cancel`. Exactly one callback runs, with a common native result and compatible
callback error type. It adapts the existing representation, giving application
examples one fold without introducing a second ADT.

| Composition | Error order |
|---|---|
| Scope / guarantee | Body, then inner-to-outer cleanup |
| Both | Left subtree, then right subtree |
| Nursery | Admission order, retaining each child's internal order |
| `race_first` | Selected subtree, then losing subtree; normalize losing cancellation only |
| Proposed `race` / `timeout_to` | Preserve all subtree errors; qualify selection and cancellation settlement before export |
| Callback | Completion error, registration error, withdrawal error |

The application surface should accept checked configuration. Propose
`Duration.nanoseconds(value)`, `.milliseconds(value)`, and `.seconds(value)` with
checked conversion and a nonnegative range. Queue capacity remains positive;
semaphore permits, nursery limits, and poll budgets remain nonnegative. Invalid
configuration raises native setup `Error`, separate from the program's exact
domain error `E`. A rejected poll budget must leave the caller owning its Driver.
Manual time is nonnegative and monotonic; invalid advances must be checked too.

The experiment currently aborts for invalid budgets, nursery limits, timer
ranges, and deadline overflow. Those checks need an explicit migration before
publication. A checked duration alone does not prove that an entry-time absolute
deadline fits in `Int`: clock range, duration range, and timer admission must be
designed together. Resolve overflow without fabricating arbitrary `E`, abandoning
an entered root, or silently truncating time. This is a focused design and test
gate. Consuming unfinished execution remains a protocol violation; ordinary
invalid configuration should not abort a host process. Duplicate callback
completion retains the documented `False` result and is not a protocol violation.

The extension protocol keeps `Machine.Value`, `Machine.Error`, and
`poll(mut self, Context[Error]) -> Step[Value, Error]`. A custom machine returns
`Step.pending(wait)` to suspend or `Step.ready(outcome)` exactly once to finish.
It is never polled after completion and must release its own entered resources
or transfer their ownership as part of its result. Outstanding external uses
and cleanup obligations must be discharged before reporting terminal state.
Direct application polling is outside the supported execution contract; Driver
and the library's child owners perform it.

Supported waits are `Wait()` for a scheduling yield, `Wait.never()` for no ordinary
wake source, `Wait.changed(signal, revision)`, and `Wait.until(deadline)`.
Cancellation remains a wake source when the context permits observation.
`Signal` exposes construction, `revision()`, and `notify()` only. Read the revision
before inspecting the associated state, then return the captured revision if
still waiting; registration rechecks it to preserve notifications before parking.
Wait fields, flattened child waits, subscriptions, and readiness evaluation stay
internal. Masked cleanup can use ordinary waits without manipulating mask fields.

`ScopedMachine` additionally receives its declared `Input` through a fresh
immutable reference each poll. `CleanupMachine` receives that loan and the exact
exit, and yields `NoneType`. Generic wrappers preserve the exact inputs, results,
errors, callable receivers, and origins. Supporting these traits does not promise
safety for implementations that violate their protocol.

## Naming concrete return types

Application code normally infers recipe types. Typed continuation factories and
generic wrappers still need public ways to name them. Retain the existing logical
names `Pure`, `Bind`, `Loop`, `Both`, `ScopedBoth`, `Scope`, `Callback`, `Sleep`,
and `Masked`. Use `RaceFirst` / `TimeoutAfter` for the preserved policies and
`Race` / `TimeoutTo` for the proposed selection policies. The experimental
`Timeout` is not a public alias. Add `Delay`, `EvalIO`, and native family result
aliases for new adapters, recovery, and resources. Only documented type
parameters, `Value`/`Error`, and protocol conformance are supported, not fields
or storage layout.

For ordinary finalization, publish `Guarantee[P, Q]`, `OnCancel[P, Q]`, and
`GuaranteeCase[P, F]` as aliases over the existing scope adapters. This deliberately
changes the experimental `Guarantee` spelling, which currently takes an already
adapted scoped finalizer. Callers must not name private `_ProgramUse` types.
Keep `Poll[E].Applied[P]` as the public result alias of `apply`.

Add associated result aliases to handle types: `Deferred[T].Complete[E]`,
`TryGet[E]`, and `Get[E]`; `Queue[T].Size[E]`, `TryOffer[E]`, `Offer[E]`,
`TryTake[E]`, and `Take[E]`; `Semaphore.Available[E]`, `Acquire[E]`, and
`WithPermit[P]`. These name the existing native recipe types and introduce no
new state, allocation, or interpreter. Callable recipe aliases use the admitted
protocol callable type. The exact return type of a native entry point can also
be named with `type_of` on its public construction expression; clients must not
spell private native adapters. Generic forwarding is part of the focused
acceptance tests, not a reason to erase callback or result types.

## Relationship to Pipeline and supported release

The first application preview requires `Async[E]` Functor/Monad family metadata
so that `pipeline(machine)` selects async composition. It must not accidentally
treat a machine as a plain value. Reuse existing family and Pipeline machinery,
native callback admission, result metadata, and deferred error capture. The
family's dependent iteration must execute through the current `Loop` owner.
Do not add another fluent wrapper, outcome type, or interpreter.

`Async[E]` names a native family dictionary; it is not a promise of the full
Cats Effect `Async[F]` capability set or a universal erased `IO[A]`. The existing
Pipeline `par_map_n` path for Result validation does not imply concurrent async
execution. Use explicit `both` for concurrency until a parallel family contract
is designed and qualified. Sequential Monad composition must remain sequential.

This application preview is larger than simply exposing the current machine
constructors. Family integration, resources, recovery, checked configuration,
and the race/timeout policy decisions are prerequisites. A machine-only
experimental export must not be described as that completed application API.

Publication should initially be an opt-in API preview, qualified for the pinned
Mojo 1.2 Linux x86-64 environment and cooperative host-thread use. Source contracts,
supported type aliases, and error/cancellation behavior are versioned; compiler
ABI, concrete layout, allocation counts, and compilation complexity are not
compatibility promises. Preview breaking changes require explicit migration notes.
The supported-release decision follows the deferred long-running qualification;
this proposal does not turn the previous correctness matrix into stress or
performance evidence.

## Implementation passes after agreement

1. **Behavior and native-signature decisions.** Qualify race/timeout cancellation
   checkpoints, error-recovery capability and laws, resumable resource
   composition, and checked timer admission. Use short deterministic probes and
   tests; agree any behavior changes before implementing them. Distinguish
   preserved policies from the proposed Cats-inspired selection explicitly.
2. **Module and host boundary.** Move the runtime to its canonical production
   owner, expose the selected namespaces and logical recipe types, hide raw Task
   and scheduler internals, add canonical context clock access, and use
   `Driver.request_cancel`. Any temporary experimental import path forwards to
   that owner instead of keeping a copy.
3. **Everyday composition.** Add `Async[E]` family and existing Pipeline support,
   iterative `tail_rec_m`, `eval_io`, `delay`, native callback admission, error
   recovery, canonical `fold_outcome`, and the finalization and handle aliases. Add compositional
   `AsyncResource` over the canonical resource owners and async scope engine.
   Keep all operation names snake_case.
4. **Concurrency policy and checked configuration.** Implement the agreed
   selection/checkpoint changes through shared race, timer, and settlement owners.
   Publish distinct preserved-policy spellings and checked configuration. Avoid
   duplicating schedulers or finalization engines to support multiple policies.
5. **Public-client qualification and documentation.** Add short runnable examples
   for Pipeline sequencing, iterative work, resource composition, error recovery,
   callback timeout, and host cancellation, including a Cats migration table.
   Verify ordinary and generic clients without private imports, move-only values,
   external origins, and rejection diagnostics through source/package O0/O3.
   Extend export/provider tooling to understand the nested public namespaces;
   update inventories, compatibility records, and installation/import guidance.
6. **Deferred overnight qualification.** Exercise sustained reuse, cancellation,
   callback/timer retirement, and bounded retained storage; measure performance
   separately. Agree the run window and budgets when scheduling this work.

All implementation passes stay in pure Mojo and integrate through shared
`nightly`. This proposal pass runs only documentation validation. Acceptance of
the proposal precedes public exports or runtime implementation changes.

[cats-flat-map]: https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/core/src/main/scala/cats/FlatMap.scala
[cats-errors]: https://github.com/typelevel/cats/blob/b055e31caf3b4922432f5423585094c3b3116eb8/core/src/main/scala/cats/ApplicativeError.scala
[ce-spawn]: https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/GenSpawn.scala
[ce-temporal]: https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/GenTemporal.scala
[ce-cancel]: https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/MonadCancel.scala
[ce-async]: https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/Async.scala
[ce-resource]: https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/Resource.scala
[ce-outcome]: https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/kernel/shared/src/main/scala/cats/effect/kernel/Outcome.scala
[ce-semaphore]: https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/std/shared/src/main/scala/cats/effect/std/Semaphore.scala
[ce-queue]: https://github.com/typelevel/cats-effect/blob/de84c01f76b2f42fcee9d43aba66c82992add103/std/shared/src/main/scala/cats/effect/std/Queue.scala
