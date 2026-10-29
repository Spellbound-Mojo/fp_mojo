# fp.effects

Reader, State and Writer describe computations that read an environment, pass
state between steps or accumulate a log. Compose them with the operations of
[fp.algebra](algebra.md), and combine effects with monad transformers such as
`ResultT` and `StateT`. The example below shows how transformer order determines
whether a failed computation returns its final state.

Start with the [effects tutorial](../tutorial/effects.md) for standalone Reader,
State and Writer programs, deferred evaluation and callback ownership.

Each transformer owns a public `CarrierCompatible[V]` predicate and its
`MapCompatible`, `BindCompatible`, `CombineCompatible` and `CollectCompatible`
operation contracts. Generic wrappers forward these predicates as described
in [algebra admission](algebra.md). Mapped, bound and conditional computations
remain valid carriers even when their concrete types differ from `Pure[A]`.

Writer collection checks its actual base loop. Linear bases accept move-only
logs, payloads and captures; a branching List base requires copyable accumulated
state. The producer must be repeatable for a repeated collection. A single
Optional or Result source can still traverse with a consuming producer.

State checks its base carrier of `(payload, state)`, Writer checks its base
carrier of `(log, payload)`, and OptionalT/ResultT check both the base and inner
carrier. Reader checks its family and environment at construction; `run`
validates the base result using the actual environment origin. These checks do
not execute deferred computations or replace their native raised errors.
Endpoint construction uses the base's carrier predicate, so a transformer over
Reader or State can accept the base's alternative computation representations.

Generic execution wrappers use `I: ReaderFamily`, `I: StateFamily`, or
`I: WriterFamily`. Reader wrappers forward `I.RunCompatible[V, o]` with the
actual borrowed environment origin. State wrappers forward
`I.RunCompatible[V]`; Writer wrappers forward `I.CarrierCompatible[V]`. Writer's `I.Unwrapped[V]` names the exact base type
returned by `run[I](value)`. The one-argument Writer overload consumes the
wrapper without executing its base. `run_writer[I](value)` remains a compatible
spelling, including its existing import path. Endpoint wrappers forward
`I.EndpointCompatible[T, F]`. Keep `I` as a type parameter: substituting a
concrete ReaderT expression inside a generic origin constraint can expand its
projections before Mojo has selected the family's complete contract.

For a type alias that selects among families with a compile-time condition,
name `Family.Endpoint[T, F]` directly. `type_of(action(...))` also checks the
call's preconditions, which may be unresolved until that condition is chosen.
Ordinary `action[Family, T](callback)` and `run[Family](value, context)` calls
retain their existing syntax.

Pipelines already select the family, so they can finish with
`pipeline(recipe).run(environment)` for Reader, `.run(initial_state)` for
State, or `.run()` for Writer. These entries delegate to the same free runners
and require the same admission predicates in generic wrappers. Reader borrows
its environment with its exact origin; State consumes its initial state.
Plain State returns `(value, final_state)`. Writer returns its base carrier of
`(log, value)`, leaving a deferred base unexecuted. `raising[E]()` selects
callback admission and does not change the recipe's execution error.
Extract with `.get()` to keep a recipe unexecuted; use `run_io` for IO's
outcome and cancellation boundary.

Selected capability scopes also stay in the chain: `.local(callback)` scopes
the current environment, `.listen()` pairs the payload with a copy of its log,
and `.censor(callback)` replaces that log. The selected family must provide the
corresponding `Local`, `Listen` or `Censor` capability. They retain the free
operations' scope, timing, origin and error rules. Explicit `LiftLocal`,
`LiftListen` and `LiftCensor` selections remain available through the free
operations for inner transformer layers.

<!-- api: effects -->

## Choose a State execution output

Use `.run_value(initial_state)` when only the payload is needed, and
`.run_state(initial_state)` when only the final state is needed. The free
functions are `run_value[Family](recipe, state)` and
`run_state[Family](recipe, state)`. Ordinary `.run(state)` still returns both.

<!-- example: docs/examples/state_outputs.mojo -->

These follow Cats' `runA` and `runS`: they map over the ordinary run result.
They preserve the base carrier, including an Optional absence or a Result
failure. A deferred base is returned without running it. The computation and
initial state are consumed once; selecting an element moves it and disposes
of the other without copying either. For a deferred base, that selection and
disposal follow the base's execution timing.

Generic wrappers forward `RunValueContract[I, V].Compatible` or
`RunStateContract[I, V].Compatible`, return `Out` and raise `Error`. Each
contract exposes `Input`, the result `Family`, `RunError` and `MapError`.
Execution and base-map construction errors must agree unless one is `Never`;
their common error is preserved exactly. Pipeline `.raising[E]()` does not
change it. Embedded value, state and error origins remain intact.

## Choose a Writer output

Finish a Writer pipeline with `.run_value()` for its payload, `.run_log()` for
its written log, or `.run()` for both. The free selected-output operations are
`run_value[Family](value)` and `run_log[Family](value)`. These correspond to
Cats' WriterT `value` and `written` projections.

<!-- example: docs/examples/writer_outputs.mojo -->

Each terminal unwraps the existing Writer carrier and maps the shared pair
selector over the base. It preserves Optional absence, Result failure and
deferred execution. The selected output moves onward; the other is disposed
of without copying. Reading the log does not need the copy that `listen` uses
to retain both the original log and an observed copy.

Generic wrappers use `WriterValueContract[I, V]` or `WriterLogContract[I, V]`:
forward `Compatible`, return `Out`, raise `Error` and retain `Family` when
continuing over the base. `Error` is base-map construction's exact native error,
independent of Pipeline `.raising[E]()`. A deferred base retains its own later
execution errors and all embedded origins. State uses the separate
`RunValueContract` and `RunStateContract` because its runner also consumes an
initial state and may raise before base mapping.

## Project without copying an environment or state

`asks[Reader[Config]](projection)` borrows Config and returns only the requested
value. `inspect[State[S]](projection)` borrows S and keeps the unchanged state.
Both work when the input is move-only; `ask` and `get` still require copying.
Callbacks run when the computation runs, and may raise their exact native error.
The projection result must be independent of the borrowed run input.

`Project` names the selected `Input` and `Family`. Use
`LiftProject[Layer, Capability]` to target an immediate base, and nest selections
for deeper stacks. Generic wrappers forward `ProjectCompatible[F]`, return
`Projected[F]` and raise `ProjectError[F]`. Native borrowing functions,
closures and stored thin pointers work directly; a consuming library callback
uses BorrowOnceCallable. A stored pointer is copied into the projection, so
reassigning the pointer later does not change an already constructed recipe.
The payload itself is borrowed at execution. Native void results remain native
void; an explicitly declared `NoneType` result keeps that distinct type.

<!-- example: docs/examples/borrowed_projections.mojo -->


## Choose whether a failure keeps its state

<!-- example: docs/examples/state_result.mojo -->

Both stacks start from state `10`, set it to `15` with `put`, then fail with
`Err("rejected")`. With `ResultT[State[Int], String]`, `run` returns the
failed `Result` together with the state `15`. With
`StateT[ResultFamily[String], Int]`, `run` returns only the `Err`, and the state
is lost with it.

## Recover stored errors through a transformer

ReaderT, WriterT, OptionalT and StateT support `ApplicativeError` when their
base Monad does. StateT also requires copyable state for this capability.
Use `.recover[Family](handler)` for a replacement value or
`.or_else[Family](handler)` for a replacement effect. Native raised errors
propagate unchanged.

StateT handlers restart from the input at the recovery boundary; ResultT above
State keeps the updated state. Reader handlers share the environment, WriterT
handlers supply their own log when the base fails, and OptionalT leaves absence
unchanged. See the [recovery reference](combinators.md#recover-a-selected-error-layer)
for the runnable comparison and ownership rules.

## Map a selected stored error

`pipeline[ResultT[M, E]](value).map_err(transform)` changes the selected inner
error type. `map_both(on_ok, on_err)` transforms each original success or error
in one base traversal, preserving their order. Outer base failures skip both
callbacks. The base need not implement `ErrorMapping`; mapping uses its existing
map operation and retains its policy.

`OptionalT[M]` supports these operations when its base Monad implements
`ErrorMapping`, including a base without recovery. An absent Optional skips the
success callback and remains absent; the error callback handles the base's
selected failure. The two layers also compose with each other.

<!-- example: docs/examples/selected_layer_error_mapping.mojo -->

ReaderT, StateT and WriterT lift the same base capability without requiring
`ApplicativeError`. Reader preserves its exact environment and borrowed run
origins. State consumes the input state once and maps the returned carrier;
it neither copies the state nor restarts it after failure. Move-only state can
therefore support mapping without recovery. Writer preserves the log value and
monoid, moving the log alongside a transformed success without recombining it.

<!-- example: docs/examples/selected_transport_error_mapping.mojo -->

Destinations retain a Monad base. OptionalT, ReaderT, StateT and WriterT wrap
the base's default error target only after checking that its actual type
implements Monad. A non-Monad candidate stays unwrapped and is rejected by the
layer's target contract. An explicitly permitted Monad destination remains
available even when the default is unusable. It must retain the exact layer,
environment, state type or log monoid. ResultT preserves its base policy and
rebinds payload-dependent metadata only when the rebound base remains a Monad.
`Target` follows existing callback bindings, so their positional meanings stay
unchanged.

Deferred bases keep callback execution and native execution errors deferred.
Construction errors retain their separate exact type. Discarding an unopened
computation disposes its captures without invoking either callback; branching
bases retain their existing repeatability requirements. Conditional source and
target aliases use the public capability witnesses described in the
[algebra reference](algebra.md).

Reader and State mapping construction raises Never; their exact native errors
belong to running the resulting action. Writer mapping exposes its base's
construction error, while a deferred base stays deferred after `run[Family]`.
The source always executes under its original family; the transformed carrier
belongs to the admitted destination. `ResultT[Reader[...], E]` instead maps its
selected inner Result over the Reader base, leaving other error layers intact.

## Program against environment capabilities

`Ask` reads a selected environment, and `Local` extends it with a temporary
scope. A capability names its `Family` and `Environment`; generic code uses
that family for algebra operations and leaves stack execution to the caller.
These are compile-time dictionaries. They introduce no runtime interface or
replacement carrier.

<!-- example: docs/examples/environment_capabilities.mojo -->

Reader families implement both capabilities for their own environment.
`LiftAsk[Layer, Capability]` lifts a read through one transformer;
`LiftLocal[Layer, Capability]` lifts both reading and scoping. The capability's
family must be the layer's immediate base. Nest these selections to cross
several layers. ReaderT, StateT, WriterT, OptionalT and ResultT support lifting.
The Identity specializations of OptionalT and ResultT have no underlying
Reader capability to select.

Selection is positional, including when multiple Readers have the same
environment type. `ReaderT[Reader[Int], Int]` selects its outer environment;
`LiftLocal[ReaderT[Reader[Int], Int], Reader[Int]]` selects the inner one.
There is no search by environment type and no implicit preference among layers.

`ask` still copies the environment when the selected Reader runs. It requires
`AskAvailable`; generic forwarders state that constraint explicitly. `local`
can use move-only environments. It consumes its computation and transformation,
borrows the current environment, and owns the changed environment during the
selected Reader's run. A native function or closure uses its usual borrowed
argument convention; a library callback can use `BorrowOnceCallable` to consume
its captures exactly once.

Generic scope forwarders retain `LocalCompatible[V]` and the equalities between
the callback's `Payload`, `Result` and the selected `Environment`. This keeps
carrier identity and embedded origins checked at the public signature. The
predicate also rejects Reader results **or native errors** that retain the
temporary environment. A deferred base can be scoped only when the particular
source returns a carrier independent of that environment. Lifting a scope to
an inner Reader preserves the outer Reader's separate borrow.

`Asked`/`AskError` and `Localized[V, F]`/`LocalError[V, F]` describe concrete
return types and native **construction** errors. A deferred carrier's `run`
retains its separate execution error. Lifting follows the existing constructor
and execution timing; it does not catch native errors as Result data. A Writer
lift may raise through its log monoid. Dropping a pending scope drops its owned
captures without invoking the transformation. Copying a scope requires copyable
stored inputs; lifting adds no copy requirement of its own.

## Program against a selected state

`Stateful` names a `Family` and a selected `StateType`. Generic code uses
`get`, `modify` and `put` with this capability, and uses `C.Family` for ordinary
algebra operations. StateT implements the capability for its own state;
`LiftStateful[Layer, Capability]` selects a state in the immediate base.
ReaderT, StateT, WriterT, OptionalT and ResultT support this explicit lifting.
Nest selections to cross multiple layers. OptionalT and ResultT specialized
over Identity have no underlying State layer to select.

<!-- example: docs/examples/stateful_capabilities.mojo -->

Selection is by position, so two State layers with identical state types remain
independent. `StateT[State[Int], Int]` selects its own outer state, while
`LiftStateful[StateT[State[Int], Int], State[Int]]` selects the inner state.
The caller still runs each layer in the stack's ordinary order.

`get` returns a copy of the state and leaves the state unchanged. It requires
`GetAvailable`, which generic forwarders must retain. `Got` and `GetError`
name its concrete carrier and native construction error. `modify` consumes the
old state and replaces it with the callback's result; its payload is `None`.
Its callback can be a library consuming callback, or a native function or
closure with a `var` state argument. Both state and captures may be move-only.
`put` uses the same modification path with an owned replacement: the previous
state is destroyed when the selected update executes.

Generic modification forwarders retain `ModifyCompatible[F]` and the equalities
`F.Arg == C.StateType` and `F.Out == C.StateType`. These preserve exact native
origins at the call boundary. `Modified[F]` and `ModifyError[F]` name the
concrete carrier and construction error. As with other capability dictionaries,
static trait methods assume admission; use the checked free functions at public
input boundaries. Third-party code can implement Stateful without implementing
the private State representation traits.

Lifting delegates to the existing layer lift. It preserves logs, unselected
states, sum short-circuiting and native error types. Construction and execution
remain separate: a deferred update does not call its callback before the
selected State runs. Dropping a pending update drops its captures without
calling it. A copied computation requires copyable stored inputs; reading
requires copyable state. Existing branching bases retain their native
repeatability and copyability requirements.

Stateful adds no rollback or error conversion. The
[stack-order example](#choose-whether-a-failure-keeps-its-state) applies equally
to selected state operations: ResultT over State can return the updated state
alongside a stored error, while StateT over Result loses the state payload on
failure. A native raised error remains a native error. External mutations
performed by a callback are not rolled back.

## Program against a selected log

`Tell` records output, `Listen` extends it with observation, and `Censor` extends
Listen with scoped log transformation. A capability names its `Family` and the
selected log `Monoid` through `Log`. WriterT implements all three for its own
log. `LiftTell`, `LiftListen` and `LiftCensor` select a capability in a layer's
immediate base; nest selections to cross several layers. ReaderT, StateT,
WriterT, OptionalT and ResultT support these selections.

<!-- example: docs/examples/writer_capabilities.mojo -->

`tell[C](log)` consumes output and produces a `None` payload.
`tell[C](log, computation)` appends to an existing computation's selected log
and preserves its payload; selected Writer chains spell this `.tell(log)`.
It delegates to `censor` with an owned, right-bound monoid combination, so
existing output precedes the appended output and no empty log is constructed.
Single-use bases consume the log; repeating bases such as List copy the
appended log per branch. The original payload can remain move-only in either
case. Construction consumes the supplied log even if the base has no payload
on which to apply it.

`listen` consumes a
computation and changes its payload from `A` to `(A, Log.Value)`, while retaining
the output log. It copies the selected log once when the selected Writer's base
mapping runs. Rearranging that pair through the outer layers moves it without
another copy. The original payload, state and other logs may be move-only.

`censor` consumes a computation and a log-to-log callback, preserving the
payload. The callback consumes the existing selected log and returns its
replacement; both log and captures may be move-only. Native functions and
closures use a `var` log argument. A dictionary can therefore support tell and
censor even when its log is not copyable and listen is unavailable. Existing
branching bases retain their callback repeatability requirements.

Both observation and transformation apply to the **supplied computation**.
Surrounding writes remain outside that scope. Listening after censor observes
the transformed log; censoring an already listened computation changes its
output log and preserves the observation already stored in its payload.
With two Writers using the same monoid, the outer Writer family selects its own
log, while `LiftCensor[OuterWriter, InnerWriter]` selects the inner log. There is
no implicit search by log type.

The layer preserves the ordinary shape of its result. For State, the observed
log belongs beside the payload, with the state still separate. For OptionalT
and ResultT it belongs inside a present or successful payload. An absent value
or stored failure supplies no successful payload to pair with the observation;
the output log itself remains where that stack ordinarily retains it.

This means censoring `ResultT[Writer, E]` transforms retained output even when
the Result is an error. Listening keeps that error and its output log, without
turning it into success. In `WriterT[ResultFamily[E], Log]`, a stored failure has
no log payload: neither the observation copy nor the censor callback runs.
Native exceptions remain native, and no operation adds rollback.

Generic append forwarders retain `TellContract[C, V].Compatible` and use its
`Family`, `Out` and `Error` projections. Its error describes construction:
an eager Writer can raise the monoid's error immediately, while a deferred
base keeps that error on its execution. Selected inner logs use an explicit
`LiftCensor` through the free two-argument `tell`.

Generic forwarders for the other entries retain `TellAvailable`, `ListenCompatible[V]`, or
`CensorCompatible[V, F]`. Censor forwarders also retain the exact equalities
between `F.Arg`, `F.Out` and `C.Log.Value`. Admission checks the selected base,
carrier shape, copyability where needed, native errors and embedded origins.
The associated `Told`/`TellError`, `Listened[V]`/`ListenError[V]`, and
`Censored[V, F]`/`CensorError[V, F]` describe concrete carriers and construction
errors. Deferred execution retains its own exact error type. Dictionary methods
assume admission; use the checked free functions at public input boundaries.

No new carrier or runtime dictionary is introduced. Dropping a deferred scope
drops its captures without invoking the callback, and copying a scope requires
copyable stored inputs. The original imports of tell, listen and censor from
the writer module remain available.

## Composable native resources

`resource[E](acquire, release)` describes a scope without acquiring it. Its
consuming `use` borrows the acquired value and returns a Result. `product`
acquires left then right; `flat_map` derives an inner recipe from an outer
value. `map` derives an owned projection while retaining its original resource;
`pure_resource[E]` wraps an existing value with native destruction. Composed
scopes release in reverse order, including after failed use or partial
acquisition. The selected E is exact: callbacks raise E or Never. A failed use
and failed release are both retained in `EffectFailure[E].errors`.

<!-- example: docs/examples/resource_scopes.mojo -->

Use `.use_void()` when acquisition and release are the whole operation. It
executes a native scope immediately and returns `Result[NoneType,
EffectFailure[E]]`; it needs no callback and does not copy the acquired value.
Composed scopes retain their acquisition order and reverse release order.

A use result or error cannot borrow the resource being released. Flat-map's
inner recipe must also be independent of that fresh outer borrow; independent
captured owners remain supported. `ResourceContract[A, R, E].Out` names a
concrete recipe in generic wrappers and factory signatures. Unopened recipes
destroy their captures without acquiring or releasing anything.

## IO, cancellation and finalization

`IO[E]` is a concrete selection of the existing Reader, Result and Optional
families. `delay[E]` suspends a native callback; `pure`, `map`, `flat_map`,
`tail_rec_m` and the existing family operations compose its recipes. `run_io`
consumes one at a host boundary. It returns `Outcome[A, E]`: None for
cancellation, Some(Ok(value)) for success, or Some(Err(EffectFailure)) for errors.
An errored outcome records cancellation too when cleanup fails after a request.

The selected Pipeline form uses `.guarantee(finalizer)` or `.on_cancel(finalizer)`
to attach cleanup, then `.run_io()` or `.run_io(token)` to execute. Cleanup
recipes must belong to the same IO error family. Construction remains deferred,
and execution consumes the pipeline once. These are thin entries into the same
free operations; `raising[E]()` does not change the selected IO family or its
outcome error. Generic wrappers forward the public `IOContract` predicates and
the pipeline's family equality.

<!-- example: docs/examples/io_execution.mojo -->

`guarantee(body, finalizer)` always finalizes an entered body, with cancellation
masked. Finalizers run from the inside out and every failure is retained.
`uncancelable` masks an entered program until its enclosing unmasked context
resumes. A `CancellationToken` can be shared with `run_io(program, token)`;
`canceled[E]()` requests cancellation from inside a program. `sleep_io[E]`
provides a monotonic wait with cooperative checks. Native callbacks run
synchronously and must return before a cancellation request can be observed.
Dropping a program or running it with an already-canceled token does not enter
its scopes or run their finalizers.

`guarantee_case(body, finalizer)` builds cleanup from an `ExitCase[E]`.
The selected form is `pipeline(body).guarantee_case(make_cleanup).run_io()`;
it accepts ordinary borrowing callbacks directly, or a consumed `ScopedIO`
factory. Native closures are borrowed until execution; owning a callback uses
the existing library callable adapters. The body retains its family, success
type and native error channel.

`GuaranteeCaseContract[Program, Factory]` exposes `Compatible`, `Out`, `Family`,
`Input`, `NativeError`, construction `Error` (Never) and execution `Outcome`.
Generic scoped-factory wrappers should forward `Compatible` instead of
restating equalities between body and finalizer aliases. `Input` is the exit
case of the body's error type; this keeps Mojo 1.2's type proofs anchored to
the selected program. No native factory error escapes construction of the
pipeline: the factory runs inside deferred finalization.

The case distinguishes success, error and cancellation; a failure can also be
canceled. `failure()` borrows its exact `EffectFailure` without copying it.
Both finalizer construction and execution are masked and captured. `on_cancel`
uses the same runner but skips cleanup unless the body observed cancellation.

<!-- example: docs/examples/io_finalization.mojo -->

`uncancelable_with[E](factory)` passes a `Poll[E]` to a deferred factory.
`poll.apply(program)` restores the cancellation state preceding that region.
An enclosing mask remains masked. A poll cannot bypass a nested mask or a
finalizer, and one retained beyond its region is inert. The existing
`uncancelable(program)` remains the simpler fully masked form.

`scoped_io(callback)` adapts an ordinary borrowing IO factory for
`guarantee_case` or resource use. It also accepts a stored thin pointer directly:
`scope.use(scoped_io(pointer))`. Admission copies the pointer and retains its
exact IO action and native construction error; it does not invoke the callback
or retain a borrow of the pointer variable. The construction error must be
`Never` or the returned IO action's error type.

Implement `ScopedIO` when the returned action needs to borrow
the exit case itself: `Action[o]` retains the input origin until execution
completes, while `Value`, `Error` and `BuildError` are independent of it.
`DelayContract[F, E].Out` names delayed actions in such generic factories.
Cleanup results and errors cannot escape that fresh borrowed input, although
independent captured origins remain supported.

Delay captures its callback's error. General algebra callbacks retain their
native error channel: use `capture_io(program)` before stored-error recovery
when a map or bind callback can raise. Existing `IO[E].or_else` and Pipeline
recovery then receive the exact `EffectFailure[E]`; cancellation skips those
handlers. Host runs and guarantees capture native errors around their bodies.

`use_resource(scope, callback)` defers one complete synchronous native resource
scope into IO. It checks cancellation before acquisition and after release;
there is no cancellation gap that can abandon an acquired value. Its callbacks
are native synchronous operations, not general origin-dependent IO callbacks.
`IOContract[P]` exposes admission and result types for generic host runners.

### Effectful resources

`resource_io(acquire, release)` describes an `IOResource`. Acquisition is an IO
program; release consumes its acquired value and returns another IO program in
the same error family. `scope.use(factory)` returns IO, deferring the complete
scope until execution. Acquisition and release run with cancellation masked;
use inherits the enclosing cancellation state. A successful acquisition always
registers release before a pending cancellation can skip use. Release runs once
on success, error or cancellation, and retains every exact error in order.

<!-- example: docs/examples/io_resources.mojo -->
Native factories returning a fixed IO type work directly. Implement `ScopedIO`
when the use action needs to borrow the acquired value while it runs: its
`Action[o]` retains that input origin, while completed values and errors cannot
escape it. Independent captured origins remain supported. Resources, callbacks
and errors may be move-only.

| Operation | Behavior |
|---|---|
| `product(other)` | Acquire left then right; release right then left. Accepts native or effectful resources in the same error family. |
| `flat_map(factory)` | Construct an inner resource from a borrowed outer value; retain outer release until the inner scope closes. |
| `map(factory)` | Project an owned value using a native callback, retaining the original resource. |
| `eval_map(factory)` | Project through IO, keeping the original resource alive while that IO borrows it. |
| `eval_tap(factory)` | Run IO over the borrowed resource and retain the original value. |
| `surround(program)` | Run an independent IO program inside the scope. |
| `use_void()` | Build IO that acquires and releases the scope with no body callback and a NoneType success payload. |
| `eval_resource(program)` | Lift cancellable IO into a resource with ordinary value destruction and no custom release. |
| `lift_resource(scope)` | Lift a native Resource into the effectful lifecycle. |

Failure or cancellation during a later acquisition or projection closes every
previously acquired scope. Each outer release observes the completed inner
scope, including errors from inner cleanup. `flat_map` does not let an inner
recipe retain the temporary borrow of its outer value; use `eval_map` or
`eval_tap` for an IO action that needs that borrow. Native Resource composition
admits native recipes only; call `lift_resource` before binding an effectful
inner resource.

Unlike native Resource, IOResource `.use_void()` remains deferred until
`run_io`. It uses the same lifecycle as `surround`: a canceled token can skip
an unopened scope; a successful acquisition registers release before honoring
cancellation. Cleanup failures remain in the exact typed outcome.

`resource_io_case(acquire, release)` adds outcome-aware cleanup. Its release
callback consumes the resource and returns a `ScopedIO` factory whose input is
`ExitCase[E]`. The factory can borrow the exact success/error/cancellation case
throughout its action. Both factory stages and execution are masked; exceptions
from any stage are captured. This two-stage signature transfers resource
ownership separately from borrowing the exit case, preserving move-only errors
without erasing origins. The example's `close_with_case` shows this pattern.

`resource_io_full[E](acquire, release)` passes `Poll[E]` to an acquisition
factory. Use `poll.apply(waiting)` for a region that may be canceled, and keep
the final acquisition handoff masked. Failed or canceled acquisition must clean
up its own partial work: registered release starts only after successful
acquisition. `resource_io_case_full` also provides outcome-aware release. A poll
retained from acquisition cannot unmask release, which has a fresh mask region.

`IOResourceContract`, `IOResourceCaseContract` and `IOResourceFullContract`
provide admission checks and concrete result types for generic code. All
lifecycle effects select the same exact error family; native construction errors
must be that type or `Never`. Dropping an unopened scope destroys captures
without running acquisition or release.

For a concrete IO resource type `S` and a `ScopedIO` factory `F`, generic
helpers forward `S.ScopedCompatible[F]`. `S.Used[F]`, `S.EvalMapped[F]` and
`S.EvalTapped[F]` name the exact results of `use`, `eval_map` and `eval_tap`.
For example, `IOResourceContract[P, R].Out.Used[F]` names a use program without
importing private lifecycle types. The resource owns the error family; the
factory must match it and the acquired input type. The scoped runner checks
`Action[o]` against the declared value and error at the fresh execution origin.

Native callbacks are adapted by the resource methods. `use`, `eval_map` and
`eval_tap` also accept stored thin pointers directly, with no adapter or extra
type arguments. The pointer is copied into the deferred program; reassigning
the caller's pointer does not change an already constructed program. Native
callbacks borrow the resource and must return an IO recipe in its error family.
They may raise that exact error type or `Never` while constructing the recipe.
Generic helpers can accept `ScopedIO` and callers can use `scoped_io(callback)`
for an input-independent action. A helper which declares a generic native
pointer type must also describe its register/memory calling convention in its
type bounds, as required by Mojo's native function ABI. The resulting action
keeps external borrow origins; it cannot borrow the fresh resource input unless
the factory implements `ScopedIO` directly.

These operations currently run through the synchronous cooperative IO backend.
They establish effectful lifecycle semantics; suspending asynchronous execution
and an async scheduler remain future runtime work.

## Shared state and coordination

`Ref[T]`, `Deferred[T]`, `Semaphore` and `Queue[T]` are shared handles: copying
one shares its state. Their operations construct IO recipes, so constructing
an update or wait does not execute it. Each method takes an explicit IO error
selection, such as `counter.get[Error]()`.

<!-- example: docs/examples/coordination.mojo -->

| Primitive | Operations | Ownership and waiting |
|---|---|---|
| `Ref[T]` | `get`, `inspect`, `update`, `modify`, `set`, `get_and_set` | Serialized state access; copying a value requires Copyable T |
| `Deferred[T]` | `complete`, `try_get`, `get` | One completion wins; waiting readers receive copies |
| `Semaphore` | `available`, `acquire`, `with_permit` | Acquisition returns an owned Permit; dropping it releases |
| `Queue[T]` | `size`, `try_offer`, `offer`, `try_take`, `take` | Bounded FIFO transfer, including move-only payloads |

`Ref.modify[E, A](callback)` atomically transforms T into `(T, A)`. The callback
must not raise: it owns the old T and must return its replacement. Use `inspect`
for a borrowing observation which may raise E. Neither operation lets a result
borrow the temporary cell access. Callbacks and state destructors must not
reenter the same Ref while it is locked. `get_and_set` transfers the previous
owner and does not require a copy.

Deferred accepts Copyable values and returns True from only its first successful
`complete`. Queue is the alternative when values must be transferred. Its
`try_offer` returns None when accepted and Some(original_value) when full.
Semaphore requires a nonnegative initial count; Queue requires positive capacity.
`with_permit(program)` releases its permit after success, failure or cancellation.
A zero-permit semaphore cannot grant a permit; a waiting acquisition can still
be canceled.

Waits check cancellation between short sleeps and promise no waiter fairness.
Native callbacks execute synchronously under the cell lock and cannot be
preempted. Cancellation does not undo an update, enqueue or dequeue that already
completed. If cancellation prevents delivery of a removed queue value, that
owned value is destroyed.

## Owned fibers

`unsafe_start(program)` immediately starts an IO recipe on one OS thread and
returns a move-only `Fiber[P]`. The current backend supports 64-bit Linux.
`fiber.join()` consumes the handle and returns its exact Outcome; `fiber.cancel()`
requests cancellation and joins. Use `fiber.request_cancel()` to signal without
waiting, and `fiber.done()` to check completion.

Starting a fiber is explicitly unsafe because Mojo has no Send/Sync proof. The
caller must ensure captured values, callbacks and destructors may cross threads,
referenced owners remain valid until join, and shared mutations are synchronized.
An accepted native closure is not evidence of thread safety. The library's shared
coordination handles provide synchronization for their own state; payloads and
callbacks retain their own obligations.

`fiber.join_io()` consumes the handle into an IO recipe. Once entered, parent
cancellation signals the child and waits for all entered child finalizers. Child
errors are retained, even during cancellation. Dropping a Fiber or an unopened
join recipe also requests cancellation and waits, discarding its outcome.
Joining can block indefinitely when native code or masked finalization does not
cooperate. Explicitly join to inspect failures. This backend uses OS threads;
it does not provide Cats-effect's lightweight scheduler.
