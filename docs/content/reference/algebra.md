# fp.algebra

`fp.algebra` provides Functor, Filterable, FunctorFilter, Applicative, ApplicativeError, Monad, Traversable, Semigroup and Monoid
interfaces. Their instances let you write generic operations over native values
such as `Optional`, `Result` and `List`; select the instance at each call. When
working with a single known type, you can also use its methods directly, such
as `Result.map`.

The [algebra tutorial](../tutorial/algebra.md) explains when to use `map`,
`map2`, `ap`, `flat_map`, `traverse` and `sequence` through optional order values.

Generic extensions can state admission using public family predicates.
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
StringDict value adapters remain private because their current dictionaries
fix the input value type; exposing them would break type-changing chains.

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

<!-- api: algebra -->

## Use one set of operations over four carriers

<!-- example: docs/examples/algebra_core.mojo -->

`map[I](twice, ...)` doubles `3` to `6` as a bare value, inside an `Optional`
and inside a `Result`, and doubles `[1, 2, 3]` to `2 4 6`; each result keeps its
native type. `flat_map[OptionalFamily](positive, Optional(-1))` lets `positive`
return an absent value. `traverse[ListFamily, OptionalFamily](positive, ...)`
returns a present list of three values for `[1, 2, 3]`, and an absent value
for `[1, -2, 3]`, stopping at `-2`.
