"""One borrowed predicate selects a continuation of an owned payload."""
from std.builtin.rebind import rebind_var
from .protocols import BorrowCallContract
from ._receiver import _borrow_once_as
from fp._internal.errors import _ErrorCompatible


def _guard_owned[P: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable,
                 G: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable,
                 selected: Bool,
                 keep: def(var P) raises X capturing -> R,
                 apply: def(var P, var G) raises X capturing -> R](
    var payload: P, var predicate: C, var function: G
) raises X -> R:
    comptime assert C.Payload == P and C.Result == Bool, "conditional: predicate must borrow the selected payload and return Bool"
    comptime assert _ErrorCompatible[X, C.Failure], "conditional: incompatible native errors"
    if rebind_var[Bool](_borrow_once_as[X](payload, predicate^)) == selected:
        return apply(payload^, function^)
    return keep(payload^)
