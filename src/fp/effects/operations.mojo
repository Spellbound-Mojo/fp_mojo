"""Run, endpoint and lifting entries shared by the effect families."""
from std.builtin.rebind import downcast, rebind, rebind_var
from fp.algebra.protocols import _Lifting
from .protocols import ReaderAction, StateAction, _Acting, _ReaderFamily, _StateFamily, _FAMILY_MISMATCH


# The family parameter selects the overload. A computation type named through
# a family's aliases (for example I.Bound[V, F] in generic code) is only known
# to be Movable & Deinitable, so each overload admits it in its body.
comptime _Reader[V: Movable & Deinitable] = downcast[V, ReaderAction]
comptime _State[V: Movable & Deinitable] = downcast[V, StateAction]


def run[V: Movable & Deinitable, o: ImmOrigin, //, I: _ReaderFamily](var action: V, ref[o] env: I.Environment
) raises _Reader[V].Error[o] -> _Reader[V].Out[o]:
    """Run a Reader computation of family `I` with a borrowed environment.

    Another overload runs a State computation with an initial state.

    Parameters:
        V: The computation's type.
        o: The environment's origin.
        I: The Reader family.

    Args:
        action: The computation, consumed.
        env: The environment, borrowed for the run.

    Returns:
        The base carrier of the payload.

    Raises:
        The common error of the stages the run executes.
    """
    comptime assert _Reader[V].Family == I, _FAMILY_MISMATCH
    return rebind_var[_Reader[V]](action^).run(rebind[_Reader[V].Env](env))


def run[V: Movable & Deinitable, //, I: _StateFamily](var action: V, var state: I.StateType
) raises _State[V].Error -> _State[V].Out:
    """Run a State computation of family `I`, consuming the initial state."""
    comptime assert _State[V].Family == I, _FAMILY_MISMATCH
    return rebind_var[_State[V]](action^).run(rebind_var[_State[V].State](state^))


def action[F: Movable & Deinitable, //, I: _Acting, T: Movable & Deinitable](var f: F) -> I.Endpoint[T, F]:
    """A computation of family `I` with payload `T` from a native endpoint callback.

    For Reader, `f` borrows the environment (a `BorrowCallable` or
    `BorrowOnceCallable`) and returns the base's carrier of `T`; for State, `f`
    is a unary callback that consumes the state and returns the base's carrier
    of `(T, state)`.

    Parameters:
        F: The callback's type.
        I: The Reader or State family.
        T: The payload type.

    Args:
        f: The callback, consumed.

    Returns:
        The computation; nothing runs now.
    """
    return I.endpoint[T](f^)


def lift[V: Movable & Deinitable, //, I: _Lifting](var value: V) raises I.LiftError[V] -> I.Lifted[V]:
    """Embed a base carrier as a value of the layer `I` over it.

    Parameters:
        V: The base carrier's type.
        I: The layer, such as `ReaderT[M, R]` or `OptionalT[M]`.

    Args:
        value: The base carrier, consumed.

    Returns:
        The layer's value.

    Raises:
        The layer's lift error; Writer's comes from its monoid's `empty`.
    """
    return I.lift(value^)

