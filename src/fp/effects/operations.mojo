"""Run, endpoint and lifting entries shared by the effect families."""
from std.builtin.rebind import downcast, rebind, rebind_var
from fp.algebra.protocols import _Lifting
from fp.algebra.contracts import MapContract
from fp.algebra._adapt import _map_as
from fp.callables._transforms import _KeepOperand
from fp._internal.errors import _CommonError, _CommonErrorCompatible, _ErrorCompatible, _propagate_error
from .protocols import ReaderAction, StateAction, _Acting, ReaderFamily, StateFamily, _FAMILY_MISMATCH


# The family parameter selects the overload. A computation type named through
# a family's aliases (for example I.Bound[V, F] in generic code) is only known
# to be Movable & Deinitable, so each overload admits it in its body.
comptime _Reader[V: Movable & Deinitable] = downcast[V, ReaderAction]
comptime _State[V: Movable & Deinitable] = downcast[V, StateAction]


def run[V: Movable & Deinitable, o: ImmOrigin, //, I: ReaderFamily](var action: V, ref[o] env: I.Environment
) raises _Reader[V].Error[o] -> _Reader[V].Out[o] where I.RunCompatible[V, o]:
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
    comptime assert I.RunCompatible[V, o], _FAMILY_MISMATCH
    comptime assert _Reader[V]._RunCompatible[o]
    return rebind_var[_Reader[V]](action^).run(rebind[_Reader[V].Env](env))


def run[V: Movable & Deinitable, //, I: StateFamily](var action: V, var state: I.StateType
) raises _State[V].Error -> _State[V].Out where I.RunCompatible[V]:
    """Run a State computation of family `I`, consuming the initial state."""
    comptime assert I.RunCompatible[V], _FAMILY_MISMATCH
    comptime assert _State[V]._RunCompatible
    return rebind_var[_State[V]](action^).run(rebind_var[_State[V].State](state^))


struct _StateRunSelection[I: StateFamily, V: Movable & Deinitable, value: Bool]:
    """Derive selected output from normal State execution and base mapping."""
    comptime Action = _State[Self.V]
    comptime Projector = _KeepOperand[Self.I.Element[Self.V], Self.I.StateType, Self.value]
    comptime Mapping = MapContract[Self.I.Base, Self.Action.Out, Self.Projector]
    comptime Compatible = Self.I.RunCompatible[Self.V] and Self.Mapping.InvocationCompatible and _CommonErrorCompatible[Self.Action.Error, Self.Mapping.Error]
    comptime Family = Self.Mapping.Family
    comptime Input = Self.I.StateType
    comptime Out = Self.Mapping.Out
    comptime RunError = Self.Action.Error
    comptime MapError = Self.Mapping.Error
    comptime Error = _CommonError[Self.RunError, Self.MapError]


comptime RunValueContract[I: StateFamily, V: Movable & Deinitable] = _StateRunSelection[I, V, True]
"""Admission, result and exact native error of running State for its value.

Generic wrappers forward Compatible, return Out and raise Error. Input names
the consumed state; Family is the resulting base family. RunError is the
recipe's execution error and MapError is base-map construction's error; they
must agree unless one is Never. A deferred base remains deferred, retaining
its own execution errors and origins. Neither tuple element requires copying.

Parameters:
    I: The selected State family, including its base Monad.
    V: The complete recipe type, including captures and origins.
"""


comptime RunStateContract[I: StateFamily, V: Movable & Deinitable] = _StateRunSelection[I, V, False]
"""Admission, result and exact native error of running State for its final state.

This shares RunValueContract's execution and mapping policy, selecting the
other element of the normal run result. Forward Compatible, Out and Error
in generic wrappers. Input names the consumed initial state and Family the
resulting base family. The unused value is disposed of without copying it.

Parameters:
    I: The selected State family, including its base Monad.
    V: The complete recipe type, including captures and origins.
"""


def _run_selected_state[V: Movable & Deinitable, //, I: StateFamily, value: Bool](var action: V, var state: I.StateType
) raises _StateRunSelection[I, V, value].Error -> _StateRunSelection[I, V, value].Out where _StateRunSelection[I, V, value].Compatible:
    comptime C = _StateRunSelection[I, V, value]
    comptime assert _ErrorCompatible[C.Error, C.RunError]
    comptime assert _ErrorCompatible[C.Error, C.MapError]
    var based: C.Action.Out
    try:
        based = run[I](action^, state^)
    except error:
        _propagate_error[C.Error](error^)
    return _map_as[C.Error, I.Base](C.Projector(), based^)


def run_value[V: Movable & Deinitable, //, I: StateFamily](var action: V, var state: I.StateType
) raises RunValueContract[I, V].Error -> RunValueContract[I, V].Out where RunValueContract[I, V].Compatible:
    """Run State for its value, preserving the base effect and discarding final state.

    Like Cats' runA, this maps over the ordinary run result. A deferred base is
    returned without executing it; absent or failed base results stay intact.

    Parameters:
        V: The computation type, including its ownership and origins.
        I: The selected State family.

    Args:
        action: The computation, consumed once.
        state: The initial state, consumed once.

    Returns:
        The base carrier of the value, without copying either tuple element.

    Raises:
        The compatible native error of State execution and base mapping.
    """
    return _run_selected_state[I, True](action^, state^)


def run_state[V: Movable & Deinitable, //, I: StateFamily](var action: V, var state: I.StateType
) raises RunStateContract[I, V].Error -> RunStateContract[I, V].Out where RunStateContract[I, V].Compatible:
    """Run State for its final state, preserving the base effect and discarding the value.

    Like Cats' runS, this maps over the ordinary run result. A deferred base is
    returned without executing it; absent or failed base results stay intact.

    Parameters:
        V: The computation type, including its ownership and origins.
        I: The selected State family.

    Args:
        action: The computation, consumed once.
        state: The initial state, consumed once.

    Returns:
        The base carrier of the final state, without copying either tuple element.

    Raises:
        The compatible native error of State execution and base mapping.
    """
    return _run_selected_state[I, False](action^, state^)


def action[F: Movable & Deinitable, //, I: _Acting, T: Movable & Deinitable](var f: F) -> I.Endpoint[T, F] where I.EndpointCompatible[T, F]:
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

