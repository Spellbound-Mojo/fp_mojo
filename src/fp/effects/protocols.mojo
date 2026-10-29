"""Effect computations and the family capabilities they share.

A computation is a concrete struct that knows how to run itself. Its associated
types name only its own parameters and those of its direct children, so a
composed computation's type is the tree of its operations. Reader results may
retain the borrowed environment, so their types take the environment origin.
A Writer value wraps its base carrier; OptionalT/ResultT values are base
carriers.
"""
from std.builtin.rebind import downcast
from fp.algebra.protocols import Monad, Monoid, _Lifting, _FamilyCarrier
from fp.callables.protocols import BorrowCallContract, UnaryContract


trait Project:
    """Borrow a selected environment or state without copying the whole value.

    The projection returns an owned result and leaves the selected input
    unchanged. Its result and error cannot borrow the temporary input of a
    run. Captured origins belonging to longer-lived owners remain intact.
    Reader and State implement this capability independently of ask/get,
    which require copying. LiftProject selects a capability through a layer.
    """
    comptime Family: Monad
    """The family in which the projection operates."""
    comptime Input: AnyType
    """The exact selected environment or state type."""
    comptime ProjectCompatible[F: BorrowCallContract & Movable & Deinitable]: Bool
    """Whether F borrows Input and has an available invocation mode."""
    comptime Projected[F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    """The concrete family carrier of the projection's result."""
    comptime ProjectError[F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    """The exact construction error; deferred execution errors stay deferred."""

    @staticmethod
    def project[F: BorrowCallContract & Movable & Deinitable](var function: F
    ) raises Self.ProjectError[F] -> Self.Projected[F]:
        """Construct one borrowed projection in this family.

        Parameters:
            F: An admitted borrowing callback.

        Args:
            function: The projection, consumed.

        Returns:
            The family's carrier of F.Result, preserving execution timing.

        Raises:
            The exact native construction error.
        """
        ...


trait Ask:
    """Read an environment in a selected effect family.

    A capability is a compile-time dictionary, not a runtime carrier. Generic
    programs use `Family` for ordinary algebra operations. `ask` copies the
    environment; forward `AskAvailable` in generic function constraints.
    Implementations must return a Family carrier whose payload is Environment.
    """
    comptime Family: Monad
    """The family in which this capability operates."""
    comptime Environment: AnyType
    """The selected environment, including its native origins."""
    comptime AskAvailable: Bool
    """Whether this selection admits copying the environment."""
    comptime Asked: Movable & Deinitable
    """The concrete carrier returned by ask."""
    comptime AskError: Movable & Deinitable
    """The exact native error of constructing ask, separate from running it."""
    @staticmethod
    def ask() raises Self.AskError -> Self.Asked:
        """Construct an environment read, when AskAvailable holds.

        Returns:
            The selected family's environment carrier.

        Raises:
            The native construction error.
        """
        ...


trait Local(Ask):
    """Scope a selected environment without changing the surrounding one.

    The callback borrows Environment and returns an owned Environment. The
    scoped computation and callback are consumed. An identity scope preserves
    the result; nested scopes compose in execution order. This capability can
    scope move-only environments even when AskAvailable is false.
    """
    comptime LocalCompatible[V: Movable & Deinitable]: Bool
    """Whether V admits this scope, preserving its family and native origins."""
    comptime Localized[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    """The concrete scoped carrier; its payload is unchanged."""
    comptime LocalError[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    """The native construction error; deferred execution has its own error."""
    @staticmethod
    def local[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.LocalError[V, F] -> Self.Localized[V, F]:
        """Construct a scope for an admitted carrier and environment callback.

        Parameters:
            V: A carrier satisfying LocalCompatible.
            F: A borrowing callback with Payload and Result equal to Environment.

        Args:
            f: The environment transformation, consumed.
            value: The computation to scope, consumed.

        Returns:
            A carrier of Family with the original payload type.

        Raises:
            The native construction error.
        """
        ...


trait Stateful:
    """Read and update a selected state in an effect family.

    This compile-time dictionary selects one state, including when a stack has
    several states of the same type. Reading copies the state; modification
    consumes it and returns its replacement. Move-only state supports updates
    without supporting get. Implementations preserve the ordinary state laws:
    get leaves state unchanged, the last put wins, and modifications compose
    in execution order. Native failures follow the selected family's semantics.
    """
    comptime Family: Monad
    """The family in which this capability operates."""
    comptime StateType: Movable & Deinitable
    """The selected state's exact type, including native origins."""
    comptime GetAvailable: Bool
    """Whether this selection admits copying the state."""
    comptime Got: Movable & Deinitable
    """The concrete carrier of StateType returned by get."""
    comptime GetError: Movable & Deinitable
    """The exact native error of constructing get, separate from running it."""
    comptime ModifyCompatible[F: UnaryContract & Movable & Deinitable]: Bool
    """Whether F is admitted, with Arg and Out exactly equal to StateType."""
    comptime Modified[F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The concrete carrier of NoneType returned by modify."""
    comptime ModifyError[F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The native construction error; execution has its own exact error."""
    @staticmethod
    def get() raises Self.GetError -> Self.Got:
        """Construct a state read when GetAvailable holds.

        Returns:
            A Family carrier whose payload is a copy of the selected state.

        Raises:
            The native construction error.
        """
        ...

    @staticmethod
    def modify[F: UnaryContract & Movable & Deinitable](var f: F) raises Self.ModifyError[F] -> Self.Modified[F]:
        """Construct an update when ModifyCompatible holds.

        Parameters:
            F: A consuming callback from StateType to StateType.

        Args:
            f: The transformation, consumed.

        Returns:
            A Family carrier with NoneType payload.

        Raises:
            The native construction error.
        """
        ...


trait Tell:
    """Append output to one explicitly selected log, in execution order.

    A compile-time capability dictionary, independent of Writer's representation.
    Tell does not require a copyable log. Its payload is NoneType.
    """
    comptime Family: Monad
    """The family in which the capability operates."""
    comptime Log: Monoid
    """The selected log monoid, retaining the exact Value type and origins."""
    comptime TellAvailable: Bool
    """Whether this selection admits constructing a log write."""
    comptime Told: Movable & Deinitable
    """The concrete carrier of NoneType returned by tell."""
    comptime TellError: Movable & Deinitable
    """The exact native construction error, separate from deferred execution."""
    @staticmethod
    def tell(var log: Self.Log.Value) raises Self.TellError -> Self.Told:
        """Construct a write when TellAvailable holds.

        Args:
            log: The output, consumed.

        Returns:
            A Family carrier with NoneType payload.

        Raises:
            The native construction error.
        """
        ...


trait Listen(Tell):
    """Observe the selected log of a computation without removing it.

    The payload becomes (value, log). Only the supplied computation is observed;
    surrounding writes remain outside that observation. Listening requires a
    copyable log, but the dictionary may still support tell for move-only logs.
    """
    comptime ListenCompatible[V: Movable & Deinitable]: Bool
    """Whether V admits observation, preserving its family and native origins."""
    comptime Listened[V: Movable & Deinitable]: Movable & Deinitable
    """The concrete Family carrier of (original payload, Log.Value)."""
    comptime ListenError[V: Movable & Deinitable]: Movable & Deinitable
    """The native construction error; execution errors remain on the carrier."""
    @staticmethod
    def listen[V: Movable & Deinitable](var value: V) raises Self.ListenError[V] -> Self.Listened[V]:
        """Observe an admitted computation's selected log.

        Parameters:
            V: A carrier satisfying ListenCompatible.

        Args:
            value: The computation, consumed.

        Returns:
            Its payload paired with a copy of its log, retaining the output log.

        Raises:
            The native construction error.
        """
        ...


trait Censor(Listen):
    """Transform the selected log of a computation, preserving its payload.

    The callback consumes the log and returns its replacement. Logs and captures
    may be move-only even when listening is unavailable. Scopes compose in
    execution order and do not affect surrounding writes or other Writer layers.
    """
    comptime CensorCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Bool
    """Whether V and F admit this scope, with Arg and Out equal to Log.Value."""
    comptime Censored[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The concrete scoped carrier, with the same payload type."""
    comptime CensorError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The native construction error, separate from execution."""
    @staticmethod
    def censor[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.CensorError[V, F] -> Self.Censored[V, F]:
        """Transform the selected log for an admitted computation and callback.

        Parameters:
            V: A carrier of Family.
            F: A consuming Log.Value-to-Log.Value transformation.

        Args:
            f: The transformation, consumed.
            value: The computation, consumed.

        Returns:
            A Family carrier preserving the original payload.

        Raises:
            The native construction error.
        """
        ...


trait _CarrierOp(Movable, Deinitable):
    """A consumed transformation of a base carrier; no stack interpretation."""
    comptime Compatible[V: Movable & Deinitable]: Bool
    comptime Applied[V: Movable & Deinitable]: Movable & Deinitable
    comptime Error[V: Movable & Deinitable]: Movable & Deinitable
    def apply[V: Movable & Deinitable](deinit self, var value: V) raises Self.Error[V] -> Self.Applied[V]: ...


trait _CapabilityLifting(_Lifting):
    comptime Base: Monad


trait _Hoisting(_CapabilityLifting):
    """Transport an admitted base operation through one representation."""
    comptime _HoistCompatible[V: Movable & Deinitable, H: _CarrierOp]: Bool
    comptime _Hoisted[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp]: Movable & Deinitable
    comptime _HoistError[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp]: Movable & Deinitable
    comptime _Listening[C: Listen, A: Movable & Deinitable]: _CarrierOp & Defaultable
    @staticmethod
    def _hoist[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp](var op: H, var value: V
    ) raises Self._HoistError[A, V, H] -> Self._Hoisted[A, V, H]: ...


trait _LocalLifting(_Hoisting):
    """Representation-specific transport of a base scope; no interpretation."""
    comptime _ScopeCompatible[C: Local, V: Movable & Deinitable]: Bool
    comptime _Scoped[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    comptime _ScopeError[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def _scope[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self._ScopeError[C, V, F] -> Self._Scoped[C, V, F]:
        ...


comptime _FAMILY_MISMATCH = "run: computation belongs to a different effect family or has an incompatible native carrier"
comptime _CHOICE_FAMILY = "choice: branches belong to different effect families"
comptime _CHOICE_VALUE = "choice: branch payload types must agree"


trait _Computation(_FamilyCarrier):
    """A value that records the effect family it belongs to and its payload."""
    pass


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
    # Additional requirements of a library recipe at the actual run origin.
    # External actions retain their existing contract through this default.
    comptime _RunCompatible[o: ImmOrigin]: Bool = True
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
    # Requirements carried by built-in recipes; custom actions keep their contract.
    comptime _RunCompatible: Bool = True
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


comptime _EndpointCompatible[M: Monad, Expected: Movable & Deinitable, Out: Movable & Deinitable] = M.CarrierCompatible[Out] and M.Element[Out] == Expected


trait _Acting(Monad):
    """A deferred family that adapts a native endpoint callback. Reader and
    State share it, so generic code can name either family's endpoint."""
    comptime Base: Monad
    comptime EndpointCompatible[T: Movable & Deinitable, F: Movable & Deinitable]: Bool
    comptime Endpoint[T: Movable & Deinitable, F: Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def endpoint[T: Movable & Deinitable, F: Movable & Deinitable](var f: F) -> Self.Endpoint[T, F]:
        ...


trait ReaderFamily(_Acting):
    """A Monad whose computations run with a borrowed Environment.

    Generic runners retain this family parameter and forward RunCompatible
    with the actual environment origin. EndpointCompatible admits action.
    """
    comptime Environment: AnyType
    comptime RunCompatible[V: Movable & Deinitable, o: ImmOrigin]: Bool


trait StateFamily(_Acting):
    """A Monad whose computations consume StateType when run.

    Generic runners forward RunCompatible; EndpointCompatible admits action.
    """
    comptime StateType: Movable & Deinitable
    comptime RunCompatible[V: Movable & Deinitable]: Bool = Self.CarrierCompatible[V]
    """Admission for running a recipe; defaults to existing carrier membership."""



trait WriterFamily(Monad):
    """A Monad carrying a Log with its payload in a Base computation.

    Unwrapped names the exact base carrier, including origins. Generic runners
    forward CarrierCompatible and return Unwrapped without private projections.
    """
    comptime Base: Monad
    comptime Log: Monoid
    comptime Unwrapped[V: Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def unwrap[V: Movable & Deinitable](var value: V) -> Self.Unwrapped[V]:
        """Remove an admitted Writer layer through its dictionary primitive.

        Parameters:
            V: A carrier admitted by CarrierCompatible.

        Args:
            value: The Writer computation, consumed.

        Returns:
            The exact base carrier, preserving its payload and origins.
        """
        ...


trait _WriterType(_Computation):
    """A Writer value: Storage is the base carrier of (log, Value)."""
    comptime Storage: Movable & Deinitable
    def into_base(deinit self) -> Self.Storage:
        ...
