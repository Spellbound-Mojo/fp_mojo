"""Effect computations and the family capabilities they share.

A computation is a concrete struct that knows how to run itself. Its associated
types name only its own parameters and those of its direct children, so a
composed computation's type is the tree of its operations. Reader results may
retain the borrowed environment, so their types take the environment origin.
A Writer value wraps its base carrier; OptionalT/ResultT values are base
carriers.
"""
from std.builtin.rebind import downcast
from fp.algebra.protocols import Monad, Monoid


comptime _FAMILY_MISMATCH = "run: computation belongs to a different effect family"
comptime _CHOICE_FAMILY = "choice: branches belong to different effect families"
comptime _CHOICE_VALUE = "choice: branch payload types must agree"


trait _Computation(Movable, Deinitable):
    """A value that records the effect family it belongs to and its payload."""
    comptime Family: AnyType
    comptime Value: Movable & Deinitable


trait ReaderAction(_Computation):
    """A computation that reads a borrowed environment when run: a value of a `ReaderT` family.

    `Family` is the `ReaderT` instance the computation belongs to and `Value`
    its payload. A result and error take the environment's origin `o`, so a
    base that keeps the environment, such as a Reader over another Reader,
    keeps its exact origin.
    """
    comptime Env: AnyType
    """The environment's type."""
    comptime Out[o: ImmOrigin]: Movable & Deinitable
    """The base carrier a run with an environment of origin `o` returns."""
    comptime Error[o: ImmOrigin]: Movable & Deinitable = Never
    """The error such a run raises; `Never` by default."""
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        """Run the computation, consuming it, with a borrowed environment.

        Parameters:
            o: The environment's origin.

        Args:
            env: The environment, borrowed for the run.

        Returns:
            The base carrier of the payload.

        Raises:
            The common error of the stages the run executes.
        """
        ...


trait StateAction(_Computation):
    """A computation that consumes a state when run and returns the base carrier of `(Value, State)`: a value of a `StateT` family."""
    comptime State: Movable & Deinitable
    """The state's type."""
    comptime Out: Movable & Deinitable
    """The base carrier a run returns."""
    comptime Error: Movable & Deinitable = Never
    """The error a run raises; `Never` by default."""
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        """Run the computation, consuming it and the state.

        Args:
            state: The initial state, consumed.

        Returns:
            The base carrier of the payload and the final state.

        Raises:
            The common error of the stages the run executes.
        """
        ...


trait _Acting(Monad):
    """A deferred family that adapts a native endpoint callback. Reader and
    State share it, so generic code can name either family's endpoint."""
    comptime Base: Monad
    comptime Endpoint[T: Movable & Deinitable, F: Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def endpoint[T: Movable & Deinitable, F: Movable & Deinitable](var f: F) -> Self.Endpoint[T, F]:
        ...


trait _ReaderFamily(_Acting):
    comptime Environment: AnyType


trait _StateFamily(_Acting):
    comptime StateType: Movable & Deinitable


def _admit_endpoint[M: Monad, Expected: Movable & Deinitable, Out: Movable & Deinitable]():
    # A native carrier must be exactly the base's carrier of the declared
    # payload; a deferred base's computation or a Writer value must belong to
    # that base.
    comptime if conforms_to(Out, _Computation):
        comptime assert downcast[Out, _Computation].Family == M and downcast[Out, _Computation].Value == Expected, "action: native result differs from declared carrier"
    else:
        comptime assert Out == M.Pure[Expected], "action: native result differs from declared carrier"


trait _WriterFamily(Monad):
    comptime Base: Monad
    comptime Log: Monoid


trait _WriterType(_Computation):
    """A Writer value: Storage is the base carrier of (log, Value)."""
    comptime Storage: Movable & Deinitable
    def into_base(deinit self) -> Self.Storage:
        ...
