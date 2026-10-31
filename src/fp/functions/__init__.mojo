"""Pipelines, compositions, argument flipping and partial application.

Start with `pipeline(value)`, chain payload operations such as `.map(function)`
or whole-value stages with `.then(function)`, and finish with `.get()`. Native
containers and declared effect recipes infer their family. Select another
family once with `pipeline[Family](value)` and select native callback errors
with `.raising[ErrorType]()`. Plain functions, closures and library callables
can be passed directly to these operations.

Use `pipe(value, f, g)` to apply a fixed sequence now, or `flow(f, g)` and
`compose(g, f)` to build a reusable composition. `flip` swaps two arguments;
`partial` binds leading arguments. `tupled(function)` adapts a binary callback
to one native pair without copying either element, while `untupled(function)`
adapts a pair consumer to two arguments. `first[Other]`, `second[Other]` and
`split(left, right)` transform pair elements; `merge(left, right)` computes
two results from one copyable input.

Two-stage `flow` and `compose` can mix a plain function or stored thin pointer
with a library callable directly, in either position. Compositions own their
stages and preserve their shared, mutable or consuming receiver capabilities.
Inferred two-stage `pipe` also accepts a native/library pair, borrowing its
shared library stage for immediate execution. Extend a saved composition with
`.then(next)` or adapt its input with `.compose(before)`.

`Pipeline.map` follows the selected family's payload and timing rules. Native
collections are eager; Reader, State and Writer retain their base's deferred
execution. `.get()` extracts the carrier; `.run(...)` executes or unwraps a
selected effect. Use `iterated` for lazy collection stages. Native callback
borrows retained by a deferred computation must outlive it.

`as_unary` and `as_binary` provide callable values when a native function must
be stored, such as inside an effect passed to `ap`. Existing `piped(value)`
and its per-method family selections remain compatibility entry points; their
signatures and native-error inference follow the compatibility guide.

`kleisli[Family](f).then(g)` composes effectful functions through the family's
monadic bind. Its `map` transforms successful payloads; ordinary container
`map(chain)` borrows the chain automatically, including in lazy iterators.
"""

from fp.callables.native import as_unary, as_binary
from .pipeline import identity, pipe
from .composition import Composition, Identity, flow, compose
from .kleisli import Kleisli, kleisli
from .flipped import Flipped, FlippedFunction, flip
from .tupled import Tupled, tupled
from .untupled import Untupled, untupled
from fp.callables.products import MappedPair
from .products import first, second, Split, split, Merge, merge
from .partial import Partial, partial

from .context import Pipeline, pipeline, pipeline_values

from ._recovery import OrElseContract
from ._outcomes import RedeemContract, RedeemWithContract
