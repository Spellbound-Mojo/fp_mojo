"""Pipelines, compositions, argument flipping and partial application.

Use `pipe(value, f, g)` to apply stages now, `flow(f, g)` or `compose(g, f)` to
build a reusable composition, and `piped(value).then(f).get()` to chain any
number of stages one call at a time. `flip` swaps two arguments and `partial`
binds leading arguments.

A stage is a plain function, a closure promoted with `as_unary`, or a library
value that implements `Unary`, such as a `Partial` or a `Composition`. Each
stage's input must equal the previous stage's result. Values move from stage to
stage without copies, stages are borrowed, and a raised error stops the chain
with its own type; a returned `Result` is ordinary data.
"""

from fp.callables.native import as_unary
from .pipeline import identity, pipe, Piped, piped
from .composition import Composition, Identity, flow, compose
from .flipped import Flipped, FlippedFunction, flip
from .partial import Partial, partial
