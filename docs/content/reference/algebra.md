# fp.algebra

For a reusable generic wrapper, follow the [contract-forwarding guide](../guides/generic-wrappers.md).

`fp.algebra` provides Functor, Filterable, FunctorFilter, Applicative, ApplicativeError, Monad, Traversable, Semigroup and Monoid
interfaces. Their instances let you write generic operations over native values
such as `Optional`, `Result` and `List`; select the instance at each call. When
working with a single known type, you can also use its methods directly, such
as `Result.map`.

The [algebra tutorial](../tutorial/algebra.md) explains when to use `map`,
`map2`, `ap`, `flat_map`, `traverse` and `sequence` through optional order values.

Generic extensions can state admission using public family predicates.
`MapContract[I, V, F]`, `BindContract[I, V, F]` and
`TraverseContract[S, G, V, F]` group an operation's `Compatible`, `Out` and
`Error` projections. A generic selected-traversal wrapper can forward one
`where TraverseContract[S, G, V, F].Compatible` instead of separately spelling
input equality and three family predicates. These compile-time descriptors
store nothing and delegate execution to the same families. They describe
library callbacks; native callbacks keep their existing admission syntax.

`FillContract[I, V, U]` and `VoidContract[I, V]` describe structural replacement
and payload discarding without naming the internal callback. Both specialize
the same map contract. Forward `InvocationCompatible`, return `Out` and raise
`Error`; project `Family` as well when returning a selected Pipeline. A
single-call family accepts a move-only replacement, while a repeated family
requires copying. Dictionary continuation follows the replacement's type.
For deferred effects, `Error` describes construction; execution keeps its
separate run requirements and native error type.

`TupleLeftContract[I, V, U]` and `TupleRightContract[I, V, U]` provide the same
projections for attaching a value before or after each payload. They specialize
the existing map contract with the shared tuple callback, so a generic wrapper
needs no private adapter type. Forward `InvocationCompatible`, `Out`, `Error`
and, for a fluent continuation, `Family`. Single-call families move the
attachment; repeated families require `Copyable`, including for empty sources.
The source, attachment and stored errors retain their independent origins.

For new map or bind wrappers, `InvocationCompatible` adds callback receiver
availability to the historical `Compatible` proof. `ReceiverCompatible` exposes
that check alone. This catches metadata-only callbacks at the wrapper boundary,
without explicit callback type bindings. Existing expanded input/family proofs
continue to forward `Compatible`; family-specific repetition and copy policies
still apply.

List mapping and binding require repeatable callbacks: shared or mutable
receivers. Their public family predicates now include that requirement.
OptionalT and ResultT propagate the admission of the actual base map, bind or
recovery primitive, so consuming callbacks reject at the checked boundary when
the base branches. Deferred bases that execute the callback once still admit
consuming receivers; move-only payloads remain supported. Generic wrappers
forwarding `Compatible` inherit these requirements without extra annotations.

Carrier membership is separate from operation eligibility. A custom family
that admits binding while rejecting mapping should define `CarrierCompatible`
explicitly; its legacy default derives membership from an identity map.
Transformer binding uses carrier membership and the base's bind predicate,
not the base's map predicate.

`FoldContract[I, V, F]` describes the free `fold_effect` entry with its inferred
construction error. A generic wrapper forwards `Compatible`, returns `Out` and
raises `Error`; `Piped.fold_effect` accepts the same proof. The native Identity,
Optional and Result folds accept move-only source items. List additionally
requires copyable items because each prepared item may enter several branches.
All four require a repeatable step. Custom families keep their existing fold
contract unless they declare additional admission requirements.

Selected `fold_effect(initial).run(step)` projects the same `FoldContract`
result and construction error. It retains the staged API's additional requirement
that the step is repeatable, and requires the bound seed to have exactly the
step's first-argument type, including origins. A generic staged wrapper forwards
`FoldContract.InvocationCompatible`, combining the unchanged `Compatible` proof
with `ReceiverCompatible` (`RepeatableBinary[F]`). Existing wrappers can retain
their two separate predicates. Custom families retain the free fold's existing
admission. The example demonstrates the free and staged forms.

<!-- example: docs/examples/fold_contracts.mojo -->

`FoldMapContract[I, M, V, F]` describes `fold_map_effect`: produce effects
with a repeatable unary callback and combine their payloads using monoid `M`.
Its `Compatible`, `Out` and `Error` projections work with free, piped, iterator
and selected-pipeline calls. This removes private fold-step types from generic
wrappers. Ordinary calls and positional type arguments retain their syntax.

The contract preserves family-specific ownership: Identity, Optional and Result
accept move-only inputs and accumulators; List requires copying where values
enter multiple branches. `Error` describes construction, including the eager
call to `M.empty()`. A deferred family still runs producers and combinations
when the resulting computation runs, with their exact native errors and origins.

<!-- example: docs/examples/fold_map_contracts.mojo -->

`FindMapContract[I, V, F]` provides the same public proof and type projections
for `find_map_effect`. The callback produces an effect of `Optional`; each live
branch stops at its first present value. Free, piped, iterator and selected
pipeline wrappers can forward `Compatible` without naming private search steps.

Empty input and an exhausted branch produce an absent inner Optional. An absent
or failed outer effect keeps the target family's usual meaning. List retains
branch order and its copying requirements; deferred families pull input and run
the callback only when the computation runs. Result and error origins remain
exact, and successful linear searches retain move-only selected values.

<!-- example: docs/examples/find_map_contracts.mojo -->

`FindContract[I, V, C]` describes `find_effect`, whose predicate borrows each
visited source element and returns an effectful Bool. The selected original
value remains owned by the search and is moved into its result. Its public
`Compatible`, `Out` and `Error` projections support the same four forwarding
routes as `FindMapContract`, including generic selected pipelines.

Borrowing searches use one predicate-derived retained type across these routes.
This lets Mojo 1.2 check generic wrappers without additional annotations relating
source-element and predicate-payload projections. Native callbacks keep their
existing signature and error admission; branching families keep their copying
requirements, while linear searches support move-only retained values.

<!-- example: docs/examples/find_contracts.mojo -->

`AnyContract[I, V, C]` and `AllContract[I, V, C]` describe `any_effect` and
`all_effect`. Both aliases share one implementation and expose `Compatible`,
`Out`, `Error`, and the input, output and family component predicates. Generic
free, piped, iterator and selected-pipeline wrappers use the same proof.

Each live branch stops at its first decisive Bool: True for `any_effect`, False
for `all_effect`. Empty input lifts False and True respectively. Borrowing
predicates retain their receiver, captures and exact native errors; absent or
failed effects and deferred execution remain controlled by the target family.

<!-- example: docs/examples/boolean_contracts.mojo -->

<!-- example: docs/examples/operation_contracts.mojo -->

`FilterContract[I, V, P]` does the same for `filter`; pass `True` as the
fourth parameter for `filter_not`. Its error and output use the actual
predicate supplied to the family, including inversion. `ReceiverCompatible`
requires a shared or mutable borrowing receiver; `Compatible` also checks the
exact payload type and Bool result. `CombineContract`
describes a binary callback and a lazy right-hand thunk; it preserves the
family's exact construction error and does not evaluate the thunk.
Its `InvocationCompatible` additionally requires invocable receivers on both the
binary callback and the right factory. `Map2Contract` and `ProductContract`
inherit these projections through their existing aliases.

Cartesian List combination requires a repeatable binary callback and copyable
operands. Its right-hand factory is invoked at most once and may consume its
captures. OptionalT and ResultT check the actual base mapping and binding
operations, so a branching base additionally requires copyable callback captures
and a copyable cached right carrier. These requirements are represented by
`CombineContract.Compatible` and apply equally to fluent `map2`, `product` and
`ap`. A generic wrapper can forward that one predicate; callers do not need
explicit callback types. Single-execution bases retain consuming callbacks and
move-only values.

<!-- example: docs/examples/selection_contracts.mojo -->

The component predicates remain available for generic implementations that
already know the input type. In particular, `FamilyCompatible` excludes the
input-equality check. Existing family predicates and generic forwarding syntax
continue to work; the legacy free-traversal boundary retains its input
requirement and checks the target operations chosen by the source.

Use `pure[I](value^)` when introducing a payload through a generic family.
It retains the family's exact `Pure[A]` type and transfers ownership without
requiring a copy. The library selects a constructor for the concrete payload;
existing custom dictionaries continue to use their static `pure` implementation.

<!-- example: docs/examples/pure_construction.mojo -->

On Mojo 1.2, a direct abstract dictionary call such as `I.pure(value^)` can still
fail compiler witness selection for Writer over Optional. The public
`pure[I](value^)` function and composed library operations avoid that boundary.
Concrete dictionary calls keep their existing syntax.

`Applicative.CarrierCompatible[V]` checks a produced carrier, including its
stored-error type and origins. `Traversable.TraverseCompatible[V, F]` checks a
source and callback. A selected traversal also checks `S.Element[V] == F.Arg`
and the source's `TargetCompatible[G, V, F]`.

Traversal checks the target operations chosen by its source family through
`S.TargetCompatible[G, V, F]`. A List source collects multiple effects; Optional
and Result sources call the producer at most once and map a wrapper over its
output. Consequently, traversing a single Optional into List supports consuming
callbacks and move-only results even though Cartesian collection does not.
`TraverseContract.TargetCompatible` exposes that decision. Its
`CollectCompatible` projection still describes direct target collection and may
be false for a valid single-value traversal.

Direct collection into Identity, Optional, Result and Validation requires a
repeatable producer and a matching iterable item type. These linear targets
accept move-only inputs, outputs and captures. Validation additionally checks
that producer and diagnostic-policy exceptions have compatible native types.
The same requirements apply when a List source collects into these targets;
single-value sources retain their consuming-callback support.

Generic wrappers abstract over both families should forward
`TraverseContract[S, G, V, F].Compatible`. Existing wrappers that spell component
predicates replace `G.CollectCompatible[V, F]` with
`S.TargetCompatible[G, V, F]`. Custom sources whose traversal does not collect
can override `TargetCompatible` with the requirements of their actual operations.

For borrowing observation, use `TraverseTapContract[S, G, V, C]` and forward
`InvocationCompatible`. `Out`, `Error` and `Family` describe the retained source
inside the target effect and its construction error. This is the contract for
Cats-style `traverseTap`: successful observations retain the original payloads.
The observer's complete result must belong to G; input and stored-error origins
remain exact. `Compatible` exposes the existing selected entry requirements.
`InvocationCompatible` also checks the observer receiver and the target map that
retains each input, including native-error compatibility. A branching List target
requires copyable originals; linear targets can retain move-only originals.
Deferred families retain their existing construction and execution timing.
These descriptors express admission; they do not adapt or invoke callbacks.

`FilterEffectContract[S, G, V, C]` is the corresponding generic contract for
`filter_effect`; S must support both Traversable and FunctorFilter. Forward
`InvocationCompatible` and project `Out`, `Error` and `Family`. The predicate
produces Bool inside G: True retains the borrowed original and False discards
it. The descriptor composes the existing retention, traversal and compaction
contracts, including their exact origins, receiver requirements and native
construction errors. `Compatible` preserves the selected entry's admission.

The source and target families determine timing. Optional calls a present
predicate during construction even when it returns a Reader computation. A List
traversal into Reader defers the predicate, retention and compaction until run.
`Error` describes construction in each case; it does not replace the deferred
computation's execution error. Compaction errors and incompatible native error
combinations are included in the checked helper contract.

<!-- example: docs/examples/single_value_traversal.mojo -->

Single-value traversal also supports deferred targets such as Reader and State.
The Optional or Result source calls the producer at construction when present or
successful; the produced action waits until `run`. Absence and stored source
errors skip the producer and remain in the target's result. Producer exceptions
and later action exceptions retain their separate native error types.

<!-- example: docs/examples/single_value_deferred.mojo -->

ListFamily mapping requires a native List, while ListFamily traversal also
accepts an owned iterable or an existing iterator. For example,
`pipeline[ListFamily](array^).traverse[OptionalFamily](check)` collects an Array
through the same source driver. An iterator resumes at its current position.
NonEmptyListFamily mapping and traversal require a NonEmptyList; filtering
continues to produce a possibly empty List. Custom families can override the
public predicates to describe their own representations.

`Filterable.FilteredFamily` and `FunctorFilter.MapFilteredFamily` name the
family returned by filtering and compaction. Both default to the implementing
family; NonEmptyListFamily selects ListFamily. Selected pipelines follow this
metadata instead of inferring semantics from native storage. Filterable remains
independent of Functor for standalone filtering. Fluent continuation requires
the resulting family to implement Functor.
Generic fluent filtering wrappers forward that requirement with
`where conforms_to(I.FilteredFamily, Functor)` when `I` is abstract.

ReaderT, StateT, WriterT, OptionalT and ResultT also implement these predicates.
Their carriers may have several concrete representations; membership does not
require equality with `Pure[A]`. See [effect admission](effects.md).

`ArrayFamily[N]`, `DequeFamily` and `LinkedListFamily` select element operations
on native sequences. Ordinary fluent code uses
`pipeline(values^).elements().map(text)`; generic code can name the family
explicitly, as in `pipeline[ArrayFamily[2]](values^).map(text)`. Both forms
preserve the Array length while changing its element type. DequeFamily and
LinkedListFamily also support filter and filter_map; ArrayFamily supports map.
None requires or claims Applicative or Monad. Deque operations preserve native
capacity and eviction settings. These names reuse the same implementations as
`piped`'s native collection methods.

Selection is explicit: `pipeline(array^)` treats the whole Array as an
Identity payload until `.elements()` selects ArrayFamily. List, Deque,
LinkedList and NonEmptyList also support `.elements()`. Dict and
StringDict values are selected with `pipeline_values(dictionary^)`. The adapter
infers the initial payload, key and hasher types and rebinds the payload after
a type-changing operation.

`RebindingFunctor` is an optional capability for families whose selection binds
a payload type. Its `WithElement[A]` names the same semantic family for payload
A. Mapping and structural mapping conveniences use it when present; ordinary
Functors retain their exact family. Filtering first selects FilteredFamily or
MapFilteredFamily; compact and filter_map then rebind the transformed payload.
No carrier is wrapped or converted for family selection.

`MapContract[I, V, F].Family` describes fluent continuation. A generic wrapper
returning a Pipeline after mapping should return
`Pipeline[MapContract[I, V, F].Family, MapContract[I, V, F].Out, E]`
instead of promising that every Functor retains the exact input family `I`.
`FilterMapContract[I, V, F]` provides the corresponding Family, Out and Error
for filter_map, with InputCompatible for its existing generic payload proof.
Generic filter_map wrappers use its Family instead of I.MapFilteredFamily.
Existing custom Functors need no new members; implementing RebindingFunctor is
only necessary when the family itself binds the payload type.

Operation contracts expose `Family`, `Out`, `Error` and `Compatible`.
For a fluent wrapper, use `Pipeline[Contract.Family, Contract.Out, E]` and
raise `Contract.Error`. Bind and combine retain their family; traversal selects
its target family. Filter follows FilteredFamily, including shape changes.

Filterable is independent of Functor: standalone filtering needs only
`Compatible`. Fluent filtering also requires
`conforms_to(I.FilteredFamily, Functor)` before projecting Family. Constructing
the returned Pipeline around the checked free filter preserves both proofs on
Mojo 1.2. A single combined alias cannot currently replace these two clauses
without breaking existing expanded generic constraints.

FilterMapContract.Compatible names its existing selected input equality.
The family primitive still checks Optional representation and callback receiver
requirements; the legacy free function's admission is unchanged. Contracts
describe forwarding requirements, not every condition a family may check when
instantiated. Existing component predicates remain available.

<!-- example: docs/examples/fluent_contracts.mojo -->

`RecoverContract[I, V, H]` describes value-returning recovery through an
`ApplicativeError` family. Generic signatures can use its `Out` and `Error`
without importing the private adapter that lifts the handler's value through
the family's `pure`. With `I: ApplicativeError`, forward `Compatible`. Expanded
selected wrappers also forward `ReceiverCompatible` and `OperationCompatible`:
the callback must supply an invocation mode and the family must admit the
adapted handler. Legacy Piped retains its existing signature predicates.

For a generic `I: Applicative` with conditional error capability, forward
`conforms_to(I, ApplicativeError)` and use the public
`downcast[I, ApplicativeError]` witness in both the contract and `recover` call.
Using different family witnesses can leave their dependent construction-error
types unrelated to the compiler. No private family alias is needed.

Both `piped(value).recover[I](handler)` and
`pipeline[I](value).recover(handler)` expose this generic capability boundary.
The descriptor's `Error` is the family's construction error: a deferred
ResultT/Reader recovery can construct without raising and later raise the
handler's exact error when run. Stored errors remain data throughout.

<!-- example: docs/examples/recovery_contract.mojo -->

`TapErrContract[I, V, C]` and `FlatTapErrContract[I, V, C]` describe borrowing
error observation. `FlatTapErrContract` requires `ApplicativeError`;
`TapErrContract` accepts a `Functor` and selects recovery first, then
`ErrorMapping`, then legacy intrinsic Result behavior for families with neither
error capability. A generic selected
wrapper forwards `Compatible` and projects `Family`, `Out` and `Error` without
importing the private observation continuation. Input equality includes the
stored error's origins; source-carrier membership is checked in both cases,
and effectful observation also checks the observer's output carrier.
`ReceiverCompatible` checks that the observer has an invocation mode;
`OperationCompatible` checks family recovery and, for effectful observation,
the finishing map and combination. `NativeErrorsCompatible` includes failure
construction and preservation errors. Family-specific branching and retained-error
copy requirements remain with the family primitives. Construction errors include the family's own recovery policy; deferred
callback and failure-constructor errors remain in the action's run contract.

For plain observation, mapping-only families delegate admission to
`MapErrContract` with the same family as the destination. The observer result
is discarded and the original stored error is moved into the output after the
borrow ends. An incompatible source, receiver, payload origin or destination
policy rejects the call; mapping errors propagate normally.

Generic `tap_err` wrappers now use `TapErrContract[I, V, C]` with the original
`I: Functor` directly, including conditional capabilities. Remove the old
recovery downcast from that contract. A wrapper that deliberately retains
`TapErrContract[downcast[I, ApplicativeError], V, C]` must select the same witness
with `pipeline[downcast[I, ApplicativeError]]`; mixing that contract witness with
`pipeline[I]` cannot forward the constraint on Mojo 1.2. Combined and component
predicate forwarding remain tested. `flat_tap_err` keeps its existing boundary.

<!-- example: docs/examples/selected_error_observation.mojo -->


`RecoverIfContract[I, V, P, H]` and `OrElseIfContract[I, V, P, H]` describe
conditional recovery. Both accept an `ApplicativeError` family, a complete
source carrier, a borrowing Bool predicate and a consuming handler. Forward
`Compatible` and project `Family`, `Out` and `Error` in a generic selected
wrapper. Value recovery retains the success payload; effect recovery also
checks that the replacement belongs to the same stored-error layer. Callback
native errors must agree unless one callback never raises. Family receiver
checks and exact construction/deferred errors remain in force. Conditional
capability wrappers use the same public `downcast[I, ApplicativeError]` witness
for the descriptor and pipeline selection.

Their complete `Compatible` predicate includes callback invocation modes,
the family's adapted recovery admission, and compatibility with failure-constructor
errors. Expanded wrappers forward the corresponding `ReceiverCompatible`,
`OperationCompatible` and `NativeErrorsCompatible` fields. Combined wrappers need
no additional predicate. These are construction contracts; deferred errors remain
with the resulting action's run contract.

<!-- example: docs/examples/selected_conditional_recovery.mojo -->

`EnsureContract[I, V, P, G]` describes selected success validation for an
`ApplicativeError & Monad` family. The predicate and error factory borrow the
source success payload, including its origins. Forward `Compatible` and
project `Family`, `Out` and `Error`; the factory must return the family's exact
stored-error type. `BindCompatible` includes the selected family's admission
of the validation continuation. An expanded generic proof must include that
bind requirement as well as the callback and source-carrier predicates.
Legacy `piped(...).ensure[I](...)` retains its existing signature requirements.
The family owns receiver checks, branching and construction errors; deferred
callback and failure-constructor errors remain in the action's run contract.
Conditional wrappers use the public `downcast[I, ApplicativeError & Monad]`
witness consistently for the descriptor and family selection.
New wrappers can forward `InvocationCompatible` to check receiver availability
as well as `Compatible`. `ReceiverCompatible` requires both the predicate and
factory to provide a shared or consuming borrowing receiver. Existing expanded
proofs remain valid, and the selected family still owns repeatability checks.

<!-- example: docs/examples/selected_validation_workflow.mojo -->

`AttemptTapContract[I,V,C]` describes selected whole-outcome observation for
an `ApplicativeError & Monad` family. `Outcome` names the exact native Result
borrowed by the observer. Generic wrappers forward `Compatible` and project
`Family`, `Out` and `Error`. The component predicates check input equality,
source and observer carrier membership, materialization through map/recovery,
and the two bind steps for observation and restoration. Forwarding all these
components is equivalent to the combined predicate; the older intrinsic
Result input checks alone do not establish the selected family contract.
Bodies retain receiver, copying, join and native-error compatibility checks.
Deferred observer and restoration errors remain in the output action's run
contract. Conditional capability wrappers use the same public
`downcast[I, ApplicativeError & Monad]` witness throughout.
`ReceiverCompatible` checks the original observer for a shared or consuming
borrowing receiver. New wrappers may forward `InvocationCompatible` to combine
that check with the existing `Compatible` proof; this does not change legacy
admission or make a consuming observer repeatable.

<!-- example: docs/examples/selected_outcome_observation.mojo -->

`FlatTapContract`, `FlatPairWithContract`, `BeforeContract` and
`FollowedByContract` describe selected Monad sequencing. Each takes the family,
complete source carrier and library callback type. Generic signatures project
`Family`, `Out` and `Error`, and forward `Compatible` to the selected operation.
Previously, an effectful pairing wrapper had to spell
`I.Bound[V, _EffectRetain[I.Element[V], I, C, False, True]]` and its matching
`I.BindError`; `FlatPairWithContract[I, V, C]` removes that private continuation
from both projections and the admission constraint.

| Contract | Callback | Successful output |
|---|---|---|
| `FlatTapContract[I, V, C]` | Borrows each payload, produces an effect | Original payloads |
| `FlatPairWithContract[I, V, C]` | Borrows each payload, produces an effect | Original/projected pairs |
| `BeforeContract[I, V, F]` | Factory producing an effect | Original payloads |
| `FollowedByContract[I, V, F]` | Factory producing an effect | Produced payloads |

`InputCompatible` checks exact borrowed payload equality, including origins;
factory adaptation satisfies it automatically. `CarrierCompatible` checks the
produced effect, and `BindCompatible` preserves the selected family's existing
bind predicate. `FamilyCompatible` combines the latter two, and `Compatible`
adds input equality. `Compatible` preserves the existing expanded generic proofs.
New wrappers can forward `InvocationCompatible` to additionally require a shared,
mutable or consuming callback receiver. `ReceiverCompatible` exposes that check
separately; factory contracts check the original factory before adapting its
ignored input. A metadata-only callback fails a checked wrapper's constraint
without explicit callback type arguments. Family bodies still validate receiver
repeatability and copying retained originals when branching.
Legacy Piped retains its input-and-carrier entry admission; its generic wrappers
can forward those component predicates without adding a bind predicate.
`Error` describes construction: deferred effects retain their separate run-time
errors. No contract invokes or stores the callback.
For a conditional Monad capability on an `Applicative` type, use the same
public `downcast[I, Monad]` witness in both the contract and `pipeline` selection.
This keeps dependent family result and error projections identical.

<!-- example: docs/examples/sequencing_contracts.mojo -->

Generic wrappers with an abstract callback return type `R` must forward the
target proof, such as `where OptionalFamily.CarrierCompatible[R]`. This also
applies to legacy sequencing, effect searches and folds. Mojo 1.2 does not
always derive the full carrier proof from an equality like `R == Optional[A]`;
use the public predicate alongside the operation's payload and error constraints.
Ordinary calls infer their concrete carrier types as before.

`filter[ListFamily](predicate, values^)` and
`filter[OptionalFamily](predicate, value^)` retain accepted original payloads.
`filter_not[Family](predicate, value^)` retains rejected payloads through the
same Filterable primitive. The predicate borrows each payload, returns Bool,
and may raise a typed error. Owned `BorrowMutableCallable` and `BorrowCallable`
values are both accepted; repeated invocation prefers the mutable receiver.
Use `mut_ref(predicate)` to inspect or reuse its updated state after the operation.
Consuming-only predicates are rejected, including for Optional.
The independent `Filterable` interface lets custom containers define selection;
`piped(value).filter[Family](predicate)` uses the same instance. See
[container filtering](../architecture/functions.md#container-preserving-filter). Named
partial predicates can be reused without copying their stored prefix at
admission. The same partial works in inferred Piped container calls and lazy
filtering; each native invocation keeps its documented bound-argument copies.


`filter_map[Family](transform, values^)` uses `FunctorFilter` to transform
payloads and retain present Optional results. `compact[Family](values^)`
derives from this primitive with the identity callback. This capability can
change payload types; it is separate from `Filterable`, which retains original
payloads. ListFamily and OptionalFamily implement both. The fluent native
container adapters also support Deque, LinkedList, Dict values and StringDict
values, as described in [fp.combinators](combinators.md).

`Semigroup` supplies associative `combine`, its value type and its native
error type. `Monoid` extends it with `empty`; existing monoids remain valid
error combiners. `ValidationFamily[ErrorCombiner]` gives native Result an
accumulating Applicative: independent failures combine in order. Its carrier
is still `Result[A, ErrorCombiner.Value]`. See
[parallel validation](combinators.md#accumulate-independent-validation-errors)
for fluent syntax and [the design](../architecture/algebra.md#accumulating-result-validation)
for the shared execution rules.

`ApplicativeError` adds a selected stored-error channel. Use
`fail[Family, A](error)` to construct a failure, and Piped's explicit-family
`recover` or `or_else` to handle it. ResultFamily, ValidationFamily and ResultT
provide instances; the remaining transformers lift the capability from their
base Monad, with copyable state required for StateT recovery. Native raised
errors stay separate. See
[selected-layer recovery](combinators.md#recover-a-selected-error-layer).

`ErrorMapping` is an optional Functor capability independent of
`ApplicativeError`. Its `bimap` primitive transforms success and the selected
stored error in one traversal. The source family admits an exact destination
through `BimapCompatible`; the destination also implements `ErrorMapping`.
`DefaultErrorTarget` is a required dictionary projection naming a candidate.
A fixed policy declares `DefaultErrorTarget[A,E] = Self`; Result declares the
new Result error family. Validation uses an explicit target
when the error type or accumulation policy changes. Neither native Result
storage nor equal payload types authorize replacing a custom family.

`MapBothContract[I,V,F,G,Target]` names the source, input, target, output and
operation predicates. Generic wrappers forward `Compatible` or all five
components and project `Family`, `Out` and `Error`. The latter describes
construction; deferred execution retains the output carrier's own contract.
`MapErrContract[I,V,G,Target]` derives the same contract using the existing
consuming Identity callback on success. Conditional wrappers use the same
public `downcast[I, ErrorMapping]` witness throughout. Native raises remain
native, callback receivers retain their ownership rules, and all payload/error
equalities include origins.
Both descriptors also expose `ReceiverCompatible` and `InvocationCompatible`.
New wrappers can forward the latter to reject missing callback receivers at
admission. The former accepts shared, mutable or consuming handlers; MapErr's
success Identity already supplies a receiver. Existing `Compatible` and expanded
proofs remain unchanged, and families retain repeatability and copying checks.

ResultFamily, ValidationFamily and all five transformer families support
this capability. `ResultT[M, E]` maps the inner Result through one `M.map`;
`M` need not implement `ErrorMapping`. OptionalT, ReaderT, StateT and WriterT
lift mapping from a base Monad that does, including a mapping-only base without
`ApplicativeError`. Optional absence, the Reader environment, owned State and
the Writer log policy remain intact. State mapping needs no copyable state or
rollback. Reader and State construct deferred actions without raising; Writer
retains its base's exact construction error and deferred execution contract.

A transformer validates the raw proposed base before wrapping it: the resulting
base must still be a Monad. A well-formed `DefaultErrorTarget` candidate alone
does not prove `OperationCompatible`. OptionalT, ReaderT, StateT and WriterT
leave a non-Monad default candidate unwrapped for normal target rejection;
an explicit permitted Monad target remains available independently of that
default. ResultT retains its deterministic base policy and any valid
`RebindingFunctor` payload reselection. Targets cannot change the selected
layer, environment, state type or log monoid.

For conditional source and destination aliases, generic selected wrappers keep
`I` and `Target` bounded by `Functor`, require their full `ErrorMapping`
conformance, and form `MapBothContract[downcast[I, ErrorMapping], V, F, G,
downcast[Target, ErrorMapping]]`. Forward its `Compatible` predicate and exact
`Family`, `Out` and `Error` projections. `MapErrContract` follows the same
pattern. These contracts remain capability-bound; `Pipeline` admits the
conditional aliases through a guarded `Functor` boundary.

<!-- example: docs/examples/selected_error_mapping.mojo -->

<!-- api: algebra -->

## Fill absence and repeat effectful steps

`or_else_absent[Base](factory, source)` supplies a lazy fallback for an Optional
inside a base effect. `get_or_else_effect[Base]` removes the Optional layer by
using an effect of the payload as its fallback. Select IdentityFamily for a
native Optional, or the base of OptionalT. Present values and base failures
skip the factory; earlier state and output are retained. A branching base calls
a repeatable factory for each absent branch.

`tail_rec_m[Family](step, initial)` repeatedly runs a step returning an effect
of `ControlFlow[B, A]`. Continue supplies the next state; Break supplies the
result. The existing effectful fold gives built-in families constant call-stack
usage in the number of steps, with no recursive callback chain. Family failure,
branching, ownership and deferred-execution rules remain in force.

<!-- example: docs/examples/absence_and_looping.mojo -->

Generic wrappers use `AbsenceContract` and `TailRecContract` to forward
`Compatible`, `Out` and `Error` for library callbacks. The latter infers B from
the step's result. Native errors retain their exact types, and are separate from
stored failures. An infinite Continue sequence stays infinite; growing state,
logs and branch results still use memory.


## Accumulate several outputs together

Use `ProductMonoid` for several independently accumulated values, and nest it
for larger products. `OptionalMonoid` adds an absent identity to a Semigroup;
`DictMonoid` merges dictionaries by combining values at duplicate keys. Both
support move-only payloads. Numeric and boolean policies make common totals
available to Writer and generic folds as well as ordinary iterator reductions.

<!-- example: docs/examples/composable_monoids.mojo -->

The product counts three records while keeping their text in order. The
dictionary merges repeated keys by addition. Boolean monoids combine already
computed values; use `any` or `all` when source traversal should short-circuit.
Floating SIMD sums retain native rounding and ordered evaluation, so their
addition must not be reassociated using the Monoid laws.

## Use one set of operations over four carriers

<!-- example: docs/examples/algebra_core.mojo -->

`map[I](twice, ...)` doubles `3` to `6` as a bare value, inside an `Optional`
and inside a `Result`, and doubles `[1, 2, 3]` to `2 4 6`; each result keeps its
native type. `flat_map[OptionalFamily](positive, Optional(-1))` lets `positive`
return an absent value. `traverse[ListFamily, OptionalFamily](positive, ...)`
returns a present list of three values for `[1, 2, 3]`, and an absent value
for `[1, -2, 3]`, stopping at `-2`.

### Conditional composition contracts

`IfContract[I, V, L, R]` describes `if_effect` with two library factories.
A generic wrapper forwards `Compatible` and names `Out` and `Error`; it does
not need the private conditional continuation or error probe. The same contract
is used by free calls, `Piped` and selected pipelines. Existing ordinary call
syntax and positional bindings stay available. A fully generic `Piped` wrapper
uses `.if_effect[G=I](left^, right^)` to distinguish its family binding from the
inferred-family overloads' error hint.

Admission checks the Bool condition, exact branch payloads and origins, carrier
membership, compatible native errors and the family's receiver requirements.
For example, List requires repeatable factories, while a single-result family
can consume either factory. `ShapeCompatible` exposes the legacy free entry's condition, branch-payload and
carrier constraints. That entry keeps its existing generic admission; the
family implementation still checks its execution requirements.
`Compatible` also includes native-error and family admission, preserving the
selected method's existing generic constraints and their expanded spelling.
`ReceiverCompatible` checks that each factory has a consuming, mutable or shared
receiver; declaring only `ThunkContract` does not provide one.
`InvocationCompatible` combines both predicates. New generic wrappers can forward
it to reject missing receivers at their boundary. Existing `Compatible` wrappers
and ordinary calls retain receiver checks during specialization. Native function
overloads keep their explicit signature and error evidence.

`Error` describes construction. A deferred family's runtime errors remain in its
returned computation; creating a conditional does not run either factory. Branch
selection, skipping on absence or failure, repeated calls and cleanup remain
owned by the family's existing bind implementation.

This executable example forwards a generic conditional with one admission
predicate.

<!-- example: docs/examples/if_contracts.mojo -->

### Contracts for already evaluated operands

`Map2Contract[I, V, W, F]` describes combining two existing carriers with a
library binary callback. It is an alias of `CombineContract` using the library's
existing owned-value adapter for the right operand. Generic code can name `Out`,
`Error` and `Compatible` without constructing or importing that private adapter.

This is still eager operand binding: both arguments already exist when `map2`
is called. The family owns subsequent invocation, branching, short-circuiting
and deferred execution. No operand or callback gains an implicit copy.

Component predicates preserve existing admission differences. Free `map2`
uses `OperationCompatible`; generic `Piped.map2` additionally checks exact
inputs; selected pipelines also require carrier membership. New wrappers may
forward `Compatible` for the complete proof. Native callback inference and
existing positional bindings are unchanged.

<!-- example: docs/examples/map2_contracts.mojo -->

`ProductContract[I, V, W]` specializes `Map2Contract` with the existing pair
callback. It provides the same result, error and admission metadata for `product`
without requiring generic wrappers to import either private adapter.

Both operands already exist when `product` is called. List pairing preserves
left-major Cartesian order and its copying requirements; optional and result
families preserve short-circuiting and cleanup of both owned operands. Deferred
families retain execution errors in the returned computation. For example,
Writer pairing may raise while combining logs, whereas pairing Reader-backed
Writers constructs a deferred computation. `Error` describes construction.

Free and generic piped calls retain `OperationCompatible`; selected pipelines
retain `FamilyCompatible`. A new wrapper can forward `Compatible` to express
the complete contract. Origins of the two payloads remain independent in the
resulting tuple, and existing positional family bindings still work.

<!-- example: docs/examples/product_contracts.mojo -->

`ProductLeftContract[I, V, W]` and `ProductRightContract[I, V, W]` specialize
the same combination contract with a payload-selection callback. Generic
wrappers forward `Compatible`, return `Out` and raise `Error`; `Family` supplies
the fluent continuation. Free `product_l[I](left, right)` and
`product_r[I](left, right)` require the complete contract, and selected
Pipeline methods check the same carrier and family admission. Move-only
payloads remain valid for single-use families. Cartesian families retain their
copying requirements, including discarded operands. No additional combination
or error-handling implementation is introduced.

### Contracts for stored callbacks

`ApContract[I, V, W]` describes applying the library callbacks in carrier `V`
to the arguments in carrier `W`. Generic wrappers can name `Out` and `Error`
and forward `Compatible` without importing private application or value
adapters. The descriptor reuses `Map2Contract` and the existing receiver
availability predicate; it adds no execution or storage layer.

`Compatible` checks the exact input type, both carriers, the family's combination
policy and a callable receiver. A shared, mutable or consuming receiver is
supported. Lists form a left-major Cartesian product and require copyable
callback and argument payloads. Each pair receives its own callback value;
mutable local callback state is not threaded between pairs. A copyable consuming
callback can therefore work in a List, while a move-only consuming callback can
work in a single-value family. Independent shared state inside a callback keeps
its existing semantics.

Admission components preserve existing generic code. Free `ap` retains
`OperationCompatible`, generic `Piped.ap` retains `InputCompatible`, and selected
pipelines retain `ShapeCompatible`. The latter combines input and family checks
without forcing a receiver proof before specialization. `ReceiverCompatible`
adds that proof in the complete `Compatible` predicate, so new generic wrappers
can reject missing receivers at their boundary. Applying the stronger predicate
to every legacy selected call would reject valid wrappers declared against
`UnaryContract`; invocation still checks their receiver when specialized.

`Error` names construction errors. Deferred families keep callback errors in the
returned computation. Exact borrowed input, output and error origins are retained;
native function values still use their existing library callable adapters.
Ordinary calls and positional family bindings are unchanged.

<!-- example: docs/examples/ap_contracts.mojo -->
