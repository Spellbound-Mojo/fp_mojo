# fp.algebra

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

<!-- example: docs/examples/operation_contracts.mojo -->

`FilterContract[I, V, P]` does the same for `filter`; pass `True` as the
fourth parameter for `filter_not`. Its error and output use the actual
predicate supplied to the family, including inversion. `CombineContract`
describes a binary callback and a lazy right-hand thunk; it preserves the
family's exact construction error and does not evaluate the thunk.

<!-- example: docs/examples/selection_contracts.mojo -->

The component predicates remain available for generic implementations that
already know the input type. In particular, `FamilyCompatible` excludes the
input-equality check. Existing family predicates and generic forwarding syntax
continue to work; the legacy free-traversal boundary retains its existing
input and target-collection requirements.

`Applicative.CarrierCompatible[V]` checks a produced carrier, including its
stored-error type and origins. `Traversable.TraverseCompatible[V, F]` checks a
source and callback. A selected traversal forwards these predicates together
with `S.Element[V] == F.Arg` and the target's `CollectCompatible[V, F]`.

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
on native sequences. For example, `pipeline[ArrayFamily[2]](values^).map(text)`
preserves the Array length while changing its element type. DequeFamily and
LinkedListFamily also support filter and filter_map; ArrayFamily supports map.
None requires or claims Applicative or Monad. Deque operations preserve native
capacity and eviction settings. These names reuse the same implementations as
`piped`'s native collection methods.

Selection is explicit: `pipeline(array^)` still treats the whole Array as an
Identity payload, while `piped(array^).map(...)` maps its elements. Dict and
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
the family's `pure`. With `I: ApplicativeError`, forward `Compatible`, or retain
the existing expanded input, output and source-carrier checks. The family still
checks its adapted handler and receiver requirements when instantiated.

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
error observation through an `ApplicativeError` family. A generic selected
wrapper forwards `Compatible` and projects `Family`, `Out` and `Error` without
importing the private observation continuation. Input equality includes the
stored error's origins; source-carrier membership is checked in both cases,
and effectful observation also checks the observer's output carrier.
The family still validates receiver repeatability and retained-error copying.
Construction errors include the family's own recovery policy; deferred
callback and failure-constructor errors remain in the action's run contract.

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
adds input equality. These are selected entry-point checks: family bodies still
validate receiver repeatability and copying retained originals when branching.
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
same Filterable primitive. The predicate borrows each payload, returns Bool, and may raise a typed error.
The independent `Filterable` interface lets custom containers define selection;
`piped(value).filter[Family](predicate)` uses the same instance. See
[container filtering](../architecture/functions.md#container-preserving-filter).

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

ResultFamily and ValidationFamily implement this capability. Custom families
can adopt it independently of recovery. Transformer implementations are not yet
provided; the [stored-error design](../architecture/mojo12-redesign.md#proposed-stored-error-rebinding)
defines their remaining requirements.

<!-- example: docs/examples/selected_error_mapping.mojo -->

<!-- api: algebra -->

## Use one set of operations over four carriers

<!-- example: docs/examples/algebra_core.mojo -->

`map[I](twice, ...)` doubles `3` to `6` as a bare value, inside an `Optional`
and inside a `Result`, and doubles `[1, 2, 3]` to `2 4 6`; each result keeps its
native type. `flat_map[OptionalFamily](positive, Optional(-1))` lets `positive`
return an absent value. `traverse[ListFamily, OptionalFamily](positive, ...)`
returns a present list of three values for `[1, 2, 3]`, and an absent value
for `[1, -2, 3]`, stopping at `-2`.
