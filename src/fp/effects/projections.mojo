"""Borrowing projections and explicit selection through transformer layers."""
from std.builtin.rebind import downcast
from fp.algebra.protocols import Monad, _Lifting
from fp.callables.protocols import BorrowCallContract
from fp.callables.native import _NativeBorrow, _Borrowing, _RaisingBorrowing
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import Project, _CapabilityLifting
from ._adapt import _lift_as


struct LiftProject[I: Monad & _Lifting, C: Project](Project):
    """Select a borrowed projection from the immediate base of a transformer.

    Nest selections to cross several layers. The underlying capability owns
    borrowing and execution; lifting adds no copies of the selected input.

    Parameters:
        I: The destination transformer family.
        C: The selected Project capability of its immediate base.
    """
    comptime Layer = downcast[Self.I, _CapabilityLifting]
    comptime Family = Self.I
    comptime Input = Self.C.Input
    comptime Projected[F: BorrowCallContract & Movable & Deinitable] = Self.I.Lifted[Self.C.Projected[F]]
    comptime ProjectError[F: BorrowCallContract & Movable & Deinitable] = _CommonError[Self.C.ProjectError[F], Self.I.LiftError[Self.C.Projected[F]]]
    comptime ProjectCompatible[F: BorrowCallContract & Movable & Deinitable] = (
        Self.Layer.Base == Self.C.Family and Self.C.ProjectCompatible[F] and
        _ErrorCompatible[Self.ProjectError[F], Self.C.ProjectError[F]] and
        _ErrorCompatible[Self.ProjectError[F], Self.I.LiftError[Self.C.Projected[F]]]
    )

    @staticmethod
    def project[F: BorrowCallContract & Movable & Deinitable](var function: F
    ) raises Self.ProjectError[F] -> Self.Projected[F]:
        """Construct the selected base projection and lift its carrier.

        Parameters:
            F: An admitted borrowing callback.

        Args:
            function: The projection, consumed.

        Returns:
            A destination carrier of F.Result.

        Raises:
            The compatible native construction errors of projection and lift.
        """
        comptime assert Self.ProjectCompatible[F], "project: incompatible capability or base family"
        comptime E = Self.ProjectError[F]
        comptime assert _ErrorCompatible[E, Self.C.ProjectError[F]]
        comptime assert _ErrorCompatible[E, Self.I.LiftError[Self.C.Projected[F]]]
        var base: Self.C.Projected[F]
        try:
            base = Self.C.project(function^)
        except error:
            _propagate_error[E](error^)
        return _lift_as[E, Self.I](base^)


def asks[F: BorrowCallContract & Movable & Deinitable, //, I: Project](var function: F
) raises I.ProjectError[F] -> I.Projected[F] where I.ProjectCompatible[F] and F.Payload == I.Input:
    """Project a selected environment without copying the environment.

    The callback borrows the input once at execution and returns an owned
    projection. Both may be move-only. Native callback overloads preserve
    captured origins and exact errors. Use LiftProject to select a base layer.
    `inspect` is the State-oriented spelling of the same Project capability.

    Parameters:
        F: The borrowing callback, including its result, error and receiver.
        I: A Project capability, such as Reader or LiftProject.

    Args:
        function: The projection, consumed; deferred families run it later.

    Returns:
        A carrier of F.Result in I.Family, with no copy of I.Input.

    Raises:
        The capability's native construction error. Callback errors follow
        execution timing and keep their exact types.
    """
    return I.project(function^)


def inspect[F: BorrowCallContract & Movable & Deinitable, //, I: Project](var function: F
) raises I.ProjectError[F] -> I.Projected[F] where I.ProjectCompatible[F] and F.Payload == I.Input:
    """Project selected state without copying or changing the state.

    State moves the unchanged state into its result after the borrow ends.
    This uses the same Project capability and invocation boundary as asks.

    Parameters:
        F: The borrowing callback, including its result, error and receiver.
        I: A Project capability, such as State or LiftProject.

    Args:
        function: The projection, consumed; it runs at execution.

    Returns:
        A carrier of F.Result in I.Family, paired with unchanged state by State.

    Raises:
        The exact native construction error, separate from deferred execution.
    """
    return asks[I](function^)


def asks[P: AnyType, R: Movable & Deinitable, //, I: Project, F: _Borrowing[P, R]](var function: F
) raises I.ProjectError[_NativeBorrow[P, R, Never, F, False]] -> I.Projected[_NativeBorrow[P, R, Never, F, False]] where I.ProjectCompatible[_NativeBorrow[P, R, Never, F, False]] and P == I.Input:
    """Project with an owned native borrowing function or closure."""
    return asks[I](_NativeBorrow[P, R, Never, F, False](function^))


def asks[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Project, F: _RaisingBorrowing[P, R, E]](var function: F
) raises I.ProjectError[_NativeBorrow[P, R, E, F, True]] -> I.Projected[_NativeBorrow[P, R, E, F, True]] where I.ProjectCompatible[_NativeBorrow[P, R, E, F, True]] and P == I.Input:
    """Project with an owned native borrowing function or closure."""
    return asks[I](_NativeBorrow[P, R, E, F, True](function^))


def inspect[P: AnyType, R: Movable & Deinitable, //, I: Project, F: _Borrowing[P, R]](var function: F
) raises I.ProjectError[_NativeBorrow[P, R, Never, F, False]] -> I.Projected[_NativeBorrow[P, R, Never, F, False]] where I.ProjectCompatible[_NativeBorrow[P, R, Never, F, False]] and P == I.Input:
    """Project with an owned native borrowing function or closure."""
    return inspect[I](_NativeBorrow[P, R, Never, F, False](function^))


def inspect[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Project, F: _RaisingBorrowing[P, R, E]](var function: F
) raises I.ProjectError[_NativeBorrow[P, R, E, F, True]] -> I.Projected[_NativeBorrow[P, R, E, F, True]] where I.ProjectCompatible[_NativeBorrow[P, R, E, F, True]] and P == I.Input:
    """Project with an owned native borrowing function or closure."""
    return inspect[I](_NativeBorrow[P, R, E, F, True](function^))
