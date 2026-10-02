"""Fixed-arity calls whose error is widened to a caller's common error type."""
from std.builtin.rebind import downcast, rebind_var
from fp._internal.errors import _ErrorCompatible, _propagate_error
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract
from fp.callables.invoke import RepeatableUnary, RepeatableBinary, call_once, call_repeated


# Error-adapting forms: a caller combining several callbacks raises one common
# native error. Evidence for the where clause comes from the caller's assertion.
def _unary_once_as[E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var arg: F.Arg
) raises E -> F.Out where _ErrorCompatible[E, F.Error]:
    try:
        return call_once(f^, arg^)
    except error:
        _propagate_error[E](error^)


def _unary_repeated_as[E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](mut f: F, var arg: F.Arg
) raises E -> F.Out where _ErrorCompatible[E, F.Error] and RepeatableUnary[F]:
    try:
        return call_repeated(f, arg^)
    except error:
        _propagate_error[E](error^)


def _binary_once_as[E: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var f: F, var first: F.First, var second: F.Second
) raises E -> F.Out where _ErrorCompatible[E, F.Error]:
    try:
        return call_once(f^, first^, second^)
    except error:
        _propagate_error[E](error^)


def _binary_repeated_as[E: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](mut f: F, var first: F.First, var second: F.Second
) raises E -> F.Out where _ErrorCompatible[E, F.Error] and RepeatableBinary[F]:
    try:
        return call_repeated(f, first^, second^)
    except error:
        _propagate_error[E](error^)


def _thunk_once_as[E: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var f: F) raises E -> F.Out where _ErrorCompatible[E, F.Error]:
    try:
        return call_once(f^)
    except error:
        _propagate_error[E](error^)
