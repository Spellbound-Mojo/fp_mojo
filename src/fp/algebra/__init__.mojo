"""Functor, Filterable, FunctorFilter, Applicative, ApplicativeError, ErrorRecovery, ErrorMapping, Monad, Traversable, Semigroup and Monoid over native values, with explicit instances.

| Interface | Primitive operations | Meaning |
|---|---|---|
| `Functor` | `map[I](value, f)` | Transform a payload without changing its context |
| `Filterable` | `filter[I](value, predicate)` | Retain accepted payloads without changing their types |
| `FunctorFilter` | `filter_map[I](value, transform)` | Transform payloads and retain present Optional results |
| `Applicative` | `pure[I](value)`, `map2_lazy[I](left, right, f)` | Introduce a payload; combine independent computations |
| `ErrorRecovery` | `I.or_else(handler, value)` | Recover the selected stored-error channel; terminal states may bypass it |
| `ApplicativeError` | `fail[I, A](error)`, `I.or_else(handler, value)` | Construct or recover the selected stored-error layer |
| `ErrorMapping` | `I.bimap[Target](on_ok, on_err, source)` | Transform success and one selected stored-error channel with an admitted destination policy |
| `Monad` | `flat_map[I](value, f)` | Choose the next computation from the current payload |
| `Traversable` | `traverse[S, G](source, f)` | Visit a source shape `S` in an applicative context `G` |
| `Semigroup` | `combine[S](left, right)` | An associative, ordered combination |
| `Monoid` | `empty[M]()`, `combine[M](left, right)` | An identity and an associative, ordered combination |

An instance is a compile-time dictionary named at each call: there are no
runtime interface objects and no global registry. The native instances are
`IdentityFamily` (the bare value), `OptionalFamily`, `ResultFamily[E]` and
`ListFamily`; `ValidationFamily[S]` uses Result storage with accumulating errors, with `StringMonoid` and `ListMonoid[A]`. `IorFamily[S]` sequences values with
warnings; `IorValidationFamily[S]` accumulates independent diagnostics. `fp.effects` adds
Reader, State, Writer and transformers. Each operation is a static method of
the instance and the functions here forward to it; its result and error types
are associated aliases of the instance, such as `I.Mapped[V, F]` and
`I.MapError[V, F]`, so generic code states them directly. The derived
operations `map2`, `ap`, `flatten` and `sequence` add no execution path.

Callbacks are fixed-arity values in any receiver mode: a `Unary` for `map`,
`flat_map` and `traverse`, a `Binary` combiner and a `Thunk` right operand for
`map2_lazy`. `map`, `flat_map` and `traverse` also take native functions and
closures directly. Operations consume carriers and callbacks. A callback that
runs repeatedly, as over a `List`, must have a shared or exclusive receiver; a
consuming-only callback is rejected when the program compiles. Native errors
propagate with their exact types; stored `Result` errors remain data.

`Filterable` is independent of Functor. ListFamily and OptionalFamily support
`filter` and its derived `filter_not`, with a repeatable borrowing predicate (`BorrowCallable` or `BorrowMutableCallable`) returning Bool. Owned predicates prefer their mutable receiver. Native
predicates are borrowed; owned library predicates are consumed. Selection runs
immediately and preserves the original payloads, origins and carrier type.

FunctorFilter extends Functor with filter_map. It may change payload types and
discard absent results; compact derives from it with identity. ListFamily and
OptionalFamily implement this capability. Custom Filterable families remain
independent and need no new methods.

A third-party instance implements the associated types and static methods of
the interfaces it claims, receives callbacks through their contracts and calls
them with `call_once` or `call_repeated` from `fp.callables`; it needs no
private library code. An Applicative-only target receives list traversal
through the default `collect`.

The functor, monad and monoid laws hold under pure, terminating callbacks and
equivalent native ownership behavior; callbacks with effects have a specified
call order and count instead.
"""
from .protocols import Functor, RebindingFunctor, Applicative, ApplicativeError, ErrorRecovery, ErrorMapping, Monad, Traversable, Monoid, Semigroup, Filterable, FunctorFilter
from .errors import fail
from .filtering import filter, filter_not, filter_map, compact
from .operations import map, pure, flat_map, map2_lazy, traverse, empty, combine
from .instances import IdentityFamily, OptionalFamily, ResultFamily, ListFamily
from .collections import ArrayFamily, DequeFamily, LinkedListFamily, FamilyOf

from ._derived import map2, product, product_l, product_r, ap, flatten, sequence
from .monoids import StringMonoid, ListMonoid, IntSumMonoid, IntProductMonoid, SIMDSumMonoid, BoolAllMonoid, BoolAnyMonoid, ProductMonoid, OptionalMonoid, DictMonoid

from .conditional import if_effect

from .validation import ValidationFamily
from .accumulate import Accumulate

from .non_empty import NonEmptyListFamily, NonEmptyListSemigroup

from .ior import IorFamily, IorValidationFamily

from .absence import or_else_absent, get_or_else_effect
from .looping import tail_rec_m
