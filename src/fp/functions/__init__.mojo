"""Pipelines, compositions, argument flipping and partial application.

Use `pipe(value, f, g)` to apply stages now, `flow(f, g)` or `compose(g, f)` to
build a reusable composition, and `piped(value).then(f).get()` to chain any
number of stages one call at a time. `flip` swaps two arguments and `partial`
binds leading arguments.

`Piped.map(transform)` preserves supported native containers, mapping their
payloads immediately through `fp.algebra`. Use `.map[Family](transform)` for an
explicit Functor instance, including third-party containers. `filter(predicate)`
also runs immediately, preserving containers that can represent rejection; `fold_left(step, initial)` consumes an iterable
immediately and keeps the accumulator in the chain. `get()` extracts the stored
value. Use `then(function)` to transform the whole value and `iterated` for lazy
element mapping and filtering.

A stage is a plain function, a closure promoted with `as_unary`, or a library
value that implements `Unary`, such as a `Partial` or a `Composition`. Each
stage's input must equal the previous stage's result. Values move from stage to
stage without copies, stages are borrowed, and a raised error stops the chain
with its own type; a returned `Result` is ordinary data.

`kleisli[Family](f).then(g)` composes effectful functions through the family's
monadic bind. Its `map` transforms successful payloads; ordinary container
`map(chain)` borrows the chain automatically, including in lazy iterators.
"""

from fp.callables.native import as_unary
from .pipeline import identity, pipe, Piped, piped
from .composition import Composition, Identity, flow, compose
from .kleisli import Kleisli, kleisli
from .flipped import Flipped, FlippedFunction, flip
from .partial import Partial, partial

from .context import Pipeline, pipeline, pipeline_values

from ._recovery import OrElseContract
