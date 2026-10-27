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
actual borrowed environment origin; State and Writer wrappers forward
`I.CarrierCompatible[V]`. Writer's `I.Unwrapped[V]` names the exact base type
returned by `run_writer`. Endpoint wrappers forward
`I.EndpointCompatible[T, F]`. Keep `I` as a type parameter: substituting a
concrete ReaderT expression inside a generic origin constraint can expand its
projections before Mojo has selected the family's complete contract.

For a type alias that selects among families with a compile-time condition,
name `Family.Endpoint[T, F]` directly. `type_of(action(...))` also checks the
call's preconditions, which may be unresolved until that condition is chosen.
Ordinary `action[Family, T](callback)` and `run[Family](value, context)` calls
retain their existing syntax.

<!-- api: effects -->

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
construction error, while a deferred base stays deferred after `run_writer`.
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

`tell` consumes output and produces a `None` payload. `listen` consumes a
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

Generic forwarders retain `TellAvailable`, `ListenCompatible[V]`, or
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
