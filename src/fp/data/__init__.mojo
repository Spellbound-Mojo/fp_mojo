"""Typed results, early termination and bridges between raised and stored errors.

`Result[T, E]` holds a success value `Ok[T]` or a stored failure `Err[E]`;
`ControlFlow[B, C]` holds `Break[B]` or `Continue[C]`. `Ior[E, A]` holds
`Left[E]`, `Right[A]` or `Both[E, A]` for values with diagnostics. These are stored in place
and matched by `fp.match`. Mojo's typed native errors are efficient; `Result`
is for failures that must be stored, collected or passed along as values, not
a replacement for `raises`.

The bridges: `attempt`, `attempt_kwargs` and `attempt_once` turn a raising call into a `Result`,
`raise_on_err` turns it back, each with the original error type, and
`collect_results` collects a source of Results into one.
"""

from .control import (
    Break,
    Continue,
    ControlFlow,
)
from ._result import (
    Err,
    Ok,
    Result,
    attempt,
    attempt_kwargs,
    attempt_once,
    mutating,
    consuming,
    mut_owned,
    mut_owned_kwargs,
    raise_on_err,
)

from .result import collect_results

from .non_empty_list import NonEmptyList

from .ior import Ior, Left, Right, Both
