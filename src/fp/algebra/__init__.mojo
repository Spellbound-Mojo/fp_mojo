"""Functor, Applicative, Monad, Traversable and Monoid over native values, with explicit instances.

| Interface | Primitive operations | Meaning |
|---|---|---|
| `Functor` | `map[I](f, value)` | Transform a payload without changing its context |
| `Applicative` | `pure[I](value)`, `map2_lazy[I](f, left, right)` | Introduce a payload; combine independent computations |
| `Monad` | `flat_map[I](f, value)` | Choose the next computation from the current payload |
| `Traversable` | `traverse[S, G](f, source)` | Visit a source shape `S` in an applicative context `G` |
| `Monoid` | `empty[M]()`, `combine[M](left, right)` | An identity and an associative, ordered combination |

An instance is a compile-time dictionary named at each call: there are no
runtime interface objects and no global registry. The native instances are
`IdentityFamily` (the bare value), `OptionalFamily`, `ResultFamily[E]` and
`ListFamily`, with `StringMonoid` and `ListMonoid[A]`; `fp.effects` adds
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

A third-party instance implements the associated types and static methods of
the interfaces it claims, receives callbacks through their contracts and calls
them with `call_once` or `call_repeated` from `fp.callables`; it needs no
private library code. An Applicative-only target receives list traversal
through the default `collect`.

The functor, monad and monoid laws hold under pure, terminating callbacks and
equivalent native ownership behavior; callbacks with effects have a specified
call order and count instead.
"""
from .protocols import Functor, Applicative, Monad, Traversable, Monoid
from .operations import map, pure, flat_map, map2_lazy, traverse, empty, combine
from .instances import IdentityFamily, OptionalFamily, ResultFamily, ListFamily

from ._derived import map2, ap, flatten, sequence
from .monoids import StringMonoid, ListMonoid
