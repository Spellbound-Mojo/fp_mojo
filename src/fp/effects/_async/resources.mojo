"""Compositional acquisition plans interpreted by the shared resumable Scope."""
from std.builtin.rebind import downcast, rebind_var
from std.os import abort
from fp.callables.protocols import BorrowCallContract, BorrowOnceCallable, Unary
from fp.callables._binding import _BorrowThunk
from fp.callables._receiver import _OnceBorrowAvailable, _borrow_once_as
from fp.callables.native import _NativeBorrow, _Borrowing, _RaisingBorrowing
from fp._internal.errors import _ErrorCompatible
from fp.effects import IOContext
from fp.effects.outcomes import _capture, _failure_as
from fp.effects.resources import _MapScopeFactory
from .kernel import Machine, Step, Wait, _Slot, _tick
from .composition import Pure, pure
from .family import _Recipe
from .scopes import ScopedMachine, CleanupMachine, Scope, _ProgramUse
from .finalization import _ScopedCleanup


struct _ScopedBuild[F: BorrowCallContract & Movable & Deinitable, E: Movable & Deinitable](ScopedMachine):
    comptime Input = downcast[Self.F.Payload, Movable & Deinitable]
    comptime Program = downcast[Self.F.Result, Machine]
    comptime Value = Self.Program.Value
    comptime Error = Self.E
    var factory: Optional[Self.F]
    var active: Optional[_Slot[Self.Program, Self.Program.Value, Self.Program.Error]]
    var completed: Bool
    def __init__(out self, var function: Self.F):
        comptime assert _OnceBorrowAvailable[Self.F] and _ErrorCompatible[Self.E, Self.F.Failure] and Self.Program.Error == Self.E
        self.factory = Optional(function^)
        self.active = None
        self.completed = False
    def poll[o: ImmOrigin](mut self, ref[o] value: Self.Input, context: IOContext[Self.E]) -> Step[Self.Value, Self.E]:
        comptime assert _OnceBorrowAvailable[Self.F] and _ErrorCompatible[Self.E, Self.F.Failure] and Self.Program.Error == Self.E
        if self.completed:
            abort("scoped factory polled after completion")
        if self.factory:
            if context.canceled():
                self.completed = True
                return .ready(None)
            # Invoke within this fresh loan. Bind cannot retain this argument
            # until a future poll; only the factory's independent owned result
            # crosses the boundary, using the same capture and slot owners.
            var made = _capture[Self.E](_BorrowThunk(self.factory.take(), Pointer(to=rebind[Self.F.Payload](value))))
            if made.is_err():
                self.completed = True
                return .ready(_failure_as[Self.Value](Optional(made^)))
            self.active = Optional(_Slot[Self.Program, Self.Program.Value, Self.Program.Error](rebind_var[Self.Program](made^._take_ok())))
            return .pending(Wait())
        _ = _tick(self.active.value(), rebind[IOContext[Self.Program.Error]](context))
        if not self.active.value().done():
            return .pending(self.active.value().waiting())
        self.completed = True
        return rebind_var[Step[Self.Value, Self.E]](self.active.value().take_step())


trait ResourcePlan(Movable, Deinitable):
    """The native bound for an inferred resource acquisition plan.

    Use this bound to name AsyncResource[P] in generic helpers. Plans are supplied
    by resource constructors and composition; AsyncResource owns their execution.
    No plan storage or independent release operation is part of this contract.
    """
    comptime Value: Movable & Deinitable
    """The owned value made available by successful acquisition."""
    comptime Error: Movable & Deinitable
    """The exact error shared by acquisition, use and release."""
    comptime _Used[U: ScopedMachine]: Machine
    """The application machine built from a scoped body descriptor."""
    def _use[U: ScopedMachine](deinit self, var body: U) -> Self._Used[U]:
        ...


@fieldwise_init
struct _Acquire[A: Machine, C: CleanupMachine](ResourcePlan):
    comptime Value = Self.A.Value
    comptime Error = Self.A.Error
    comptime _Used[U: ScopedMachine] = Scope[Self.A, U, Self.C]
    """The application machine built from a scoped body descriptor."""
    var acquire: Self.A
    var cleanup: Self.C
    def _use[U: ScopedMachine](deinit self, var body: U) -> Self._Used[U]:
        return Self._Used[U](self.acquire^, body^, self.cleanup^)


trait _AsyncResourceType(Movable, Deinitable):
    comptime Plan: ResourcePlan
    def _into_plan(deinit self) -> Self.Plan:
        ...


@fieldwise_init
struct _UseResource[F: BorrowCallContract & Movable & Deinitable, U: ScopedMachine](BorrowOnceCallable):
    comptime Payload = Self.F.Payload
    comptime Right = downcast[Self.F.Result, _AsyncResourceType].Plan
    comptime Result = Self.Right._Used[Self.U]
    comptime Failure = Self.F.Failure
    var factory: Self.F
    var body: Self.U
    def invoke_once(deinit self, ref value: Self.Payload) raises Self.Failure -> Self.Result:
        var resource = _borrow_once_as[Self.Failure](value, self.factory^)
        return rebind_var[downcast[Self.F.Result, _AsyncResourceType]](resource^)._into_plan()._use(self.body^)


@fieldwise_init
struct _Join[L: ResourcePlan, F: BorrowCallContract & Movable & Deinitable](ResourcePlan):
    comptime Right = downcast[Self.F.Result, _AsyncResourceType].Plan
    comptime Value = Self.Right.Value
    comptime Error = Self.L.Error
    comptime _Used[U: ScopedMachine] = Self.L._Used[_ScopedBuild[_UseResource[Self.F, U], Self.Error]]
    """The application machine built from a scoped body descriptor."""
    var left: Self.L
    var factory: Self.F
    def _use[U: ScopedMachine](deinit self, var body: U) -> Self._Used[U]:
        return self.left^._use(_ScopedBuild[_UseResource[Self.F, U], Self.Error](_UseResource(self.factory^, body^)))


@fieldwise_init
struct _PureFactory[T: Movable & Deinitable, E: Movable & Deinitable](Unary, Defaultable):
    comptime Arg = Self.T
    comptime Cleanup = _ScopedCleanup[_ProgramUse[Pure[NoneType, Self.E], Self.T], False, True]
    comptime Out = AsyncResource[_Acquire[Pure[Self.T, Self.E], Self.Cleanup]]
    def call(self, var value: Self.T) -> Self.Out:
        var unit: NoneType = None
        return resource(pure[Self.E](value^), _ProgramUse[Pure[NoneType, Self.E], Self.T](pure[Self.E](unit)))


@fieldwise_init
struct AsyncResource[P: ResourcePlan](_AsyncResourceType):
    """An unopened resource plan, consumed by composition or scoped use.

    Acquisitions and releases may suspend. Each use runs through the canonical
    Scope engine: acquisition and cleanup are masked, release order is reversed,
    and failures retain body-before-cleanup order. Fresh resource loans last one
    callback invocation or poll; they cannot escape into returned machines.

    Parameters:
        P: The inferred concrete acquisition plan, including all owned captures.
    """
    comptime Plan = Self.P
    """The concrete unopened plan; infer this parameter from constructors."""
    comptime Value = Self.P.Value
    """The owned resource value lent during use."""
    comptime Error = Self.P.Error
    """The exact domain error of acquisition, use and cleanup."""
    comptime Used[U: ScopedMachine] = _Recipe[Self.P._Used[U]]
    """The application machine built from a scoped body descriptor."""
    comptime Use[F: BorrowCallContract & Movable & Deinitable] = Self.Used[_ScopedBuild[F, Self.Error]]
    """The application machine built by a borrowing body factory."""
    comptime _FactoryCompatible[F: BorrowCallContract & Movable & Deinitable] = F.Payload == Self.Value and _OnceBorrowAvailable[F] and _ErrorCompatible[Self.Error, F.Failure]
    comptime MapCompatible[F: BorrowCallContract & Movable & Deinitable] = Self._FactoryCompatible[F]
    """Exact borrowed input, receiver and factory-error admission for map."""
    comptime UseCompatible[F: BorrowCallContract & Movable & Deinitable] = Self._FactoryCompatible[F] and conforms_to(F.Result, Machine) and downcast[F.Result, Machine].Error == Self.Error
    """Exact borrowing factory admission and independently owned body error family."""
    comptime BindCompatible[F: BorrowCallContract & Movable & Deinitable] = Self._FactoryCompatible[F] and conforms_to(F.Result, _AsyncResourceType) and downcast[F.Result, _AsyncResourceType].Plan.Error == Self.Error
    """Exact borrowing factory admission and dependent resource error family."""
    comptime Bound[F: BorrowCallContract & Movable & Deinitable] = AsyncResource[_Join[Self.P, F]]
    """The dependent resource recipe returned by flat_map."""
    comptime Mapped[F: BorrowCallContract & Movable & Deinitable] = AsyncResource[_Join[Self.P, _MapScopeFactory[F, Self.Error, _PureFactory[F.Result, Self.Error]]]]
    """The resource recipe retaining release ownership after map."""
    var _plan: Self.P
    def _into_plan(deinit self) -> Self.P:
        return self._plan^
    def use[U: ScopedMachine](deinit self, var body: U) -> Self.Used[U] where U.Input == Self.Value and U.Error == Self.Error:
        """Lend the resource afresh for each poll, then drain its release.

        Parameters:
            U: A scoped machine with the exact resource input and domain error.

        Args:
            body: The unopened body, consumed once.

        Returns:
            A machine owning the complete acquisition, body and cleanup lifetime.
        """
        return _Recipe(self._plan^._use(body^))
    def use[F: BorrowCallContract & Movable & Deinitable](deinit self, var body: F) -> Self.Use[F] where Self.UseCompatible[F]:
        """Build an independently owned body through one fresh resource loan.

        Parameters:
            F: A once-admitted borrowing factory returning an owned machine.

        Args:
            body: The factory, deferred until successful acquisition.

        Returns:
            A machine that captures compatible factory errors and always releases
            an acquired resource; the returned body cannot retain the fresh loan.
        """
        return self^.use(_ScopedBuild[F, Self.Error](body^))
    def flat_map[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F) -> Self.Bound[F] where Self.BindCompatible[F]:
        """Acquire a dependent resource and release it before this resource.

        Parameters:
            F: A once-admitted borrowing factory returning another AsyncResource.

        Args:
            function: The deferred factory, owning its captures.

        Returns:
            An unopened plan exposing the inner value while retaining both owners.
        """
        return AsyncResource(_Join(self._plan^, function^))
    def map[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F) -> Self.Mapped[F] where Self.MapCompatible[F]:
        """Project an owned value while retaining the original release owner.

        Parameters:
            F: A once-admitted borrowing projection with a compatible native error.

        Args:
            function: The projection, deferred until successful acquisition.

        Returns:
            An unopened resource plan; the result cannot retain the fresh input loan.
        """
        return self^.flat_map(_MapScopeFactory[F, Self.Error, _PureFactory[F.Result, Self.Error]](function^))

    def use[A: AnyType, R: Movable & Deinitable, //, F: _Borrowing[A, R]](deinit self, var function: F) -> Self.Use[_NativeBorrow[A, R, Never, F, False]] where Self.UseCompatible[_NativeBorrow[A, R, Never, F, False]]:
        """Adapt a native borrowing callback through the canonical callable boundary."""
        return self^.use(_NativeBorrow[A, R, Never, F, False](function^))

    def use[A: AnyType, R: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[A, R, X]](deinit self, var function: F) -> Self.Use[_NativeBorrow[A, R, X, F, True]] where Self.UseCompatible[_NativeBorrow[A, R, X, F, True]]:
        """Adapt a native borrowing callback through the canonical callable boundary."""
        return self^.use(_NativeBorrow[A, R, X, F, True](function^))

    def map[A: AnyType, R: Movable & Deinitable, //, F: _Borrowing[A, R]](deinit self, var function: F) -> Self.Mapped[_NativeBorrow[A, R, Never, F, False]] where Self.MapCompatible[_NativeBorrow[A, R, Never, F, False]]:
        """Adapt a native borrowing callback through the canonical callable boundary."""
        return self^.map(_NativeBorrow[A, R, Never, F, False](function^))

    def map[A: AnyType, R: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[A, R, X]](deinit self, var function: F) -> Self.Mapped[_NativeBorrow[A, R, X, F, True]] where Self.MapCompatible[_NativeBorrow[A, R, X, F, True]]:
        """Adapt a native borrowing callback through the canonical callable boundary."""
        return self^.map(_NativeBorrow[A, R, X, F, True](function^))

    def flat_map[A: AnyType, R: Movable & Deinitable, //, F: _Borrowing[A, R]](deinit self, var function: F) -> Self.Bound[_NativeBorrow[A, R, Never, F, False]] where Self.BindCompatible[_NativeBorrow[A, R, Never, F, False]]:
        """Adapt a native borrowing callback through the canonical callable boundary."""
        return self^.flat_map(_NativeBorrow[A, R, Never, F, False](function^))

    def flat_map[A: AnyType, R: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[A, R, X]](deinit self, var function: F) -> Self.Bound[_NativeBorrow[A, R, X, F, True]] where Self.BindCompatible[_NativeBorrow[A, R, X, F, True]]:
        """Adapt a native borrowing callback through the canonical callable boundary."""
        return self^.flat_map(_NativeBorrow[A, R, X, F, True](function^))


def resource_case[A: Machine, C: CleanupMachine](var acquire: A, var release: C) -> ResourceCase[A, C] where A.Value == C.Input and A.Error == C.Error:
    """Build a resource plan whose release borrows the exact exit case.

    Parameters:
        A: The concrete acquisition machine.
        C: The cleanup descriptor with matching input and domain error.

    Args:
        acquire: Unopened acquisition, consumed once when run.
        release: Suspensible cleanup, installed before body entry.

    Returns:
        An unopened resource plan; failed acquisition executes no release.
    """
    return AsyncResource(_Acquire(acquire^, release^))


def resource[A: Machine, C: ScopedMachine](var acquire: A, var release: C) -> Resource[A, C] where A.Value == C.Input and A.Error == C.Error:
    """Build a resource plan with a scoped, suspensible release.

    Parameters:
        A: The concrete acquisition machine.
        C: The scoped release descriptor with matching input and domain error.

    Args:
        acquire: Unopened acquisition, consumed once when run.
        release: Cleanup borrowing the acquired resource each poll.

    Returns:
        An unopened resource plan; successful release values are discarded.
    """
    return resource_case(acquire^, _ScopedCleanup[C, False, True](release^))


comptime Resource[A: Machine, C: ScopedMachine] = AsyncResource[_Acquire[A, _ScopedCleanup[C, False, True]]]
"""A resource built with a suspensible scoped release descriptor.

Parameters:
    A: The acquisition machine.
    C: The release descriptor borrowing A.Value with the exact same error.
"""


comptime ResourceCase[A: Machine, C: CleanupMachine] = AsyncResource[_Acquire[A, C]]
"""A resource whose release also borrows the exact exit case.

Parameters:
    A: The acquisition machine.
    C: The cleanup descriptor borrowing A.Value and ExitCase[A.Error].
"""


comptime ResourceFactory[A: Machine, F: BorrowCallContract & Movable & Deinitable] = Resource[A, _ScopedBuild[F, A.Error]]
"""A resource whose release factory builds an independently owned machine.

Parameters:
    A: The acquisition machine.
    F: The borrowing release factory, called under the cleanup mask.
"""


def resource[A: Machine, F: BorrowCallContract & Movable & Deinitable](var acquire: A, var release: F) -> ResourceFactory[A, F] where F.Payload == A.Value and _OnceBorrowAvailable[F] and _ErrorCompatible[A.Error, F.Failure] and conforms_to(F.Result, Machine) and downcast[F.Result, Machine].Error == A.Error:
    """Build masked cleanup through a fresh loan of the acquired resource.

    Parameters:
        A: The acquisition machine.
        F: The once-admitted borrowing release factory.

    Args:
        acquire: Unopened acquisition, consumed once when run.
        release: A factory returning an independently owned cleanup machine.

    Returns:
        A resource plan that captures factory errors as cleanup failures.
    """
    return resource(acquire^, _ScopedBuild[F, A.Error](release^))


def resource[A: Machine, T: AnyType, R: Machine, //, F: _Borrowing[T, R]](var acquire: A, var release: F) -> ResourceFactory[A, _NativeBorrow[T, R, Never, F, False]] where T == A.Value and R.Error == A.Error:
    """Adapt a native release factory through the canonical borrowing boundary."""
    return resource(acquire^, _NativeBorrow[T, R, Never, F, False](release^))


def resource[A: Machine, T: AnyType, R: Machine, X: Movable & Deinitable, //, F: _RaisingBorrowing[T, R, X]](var acquire: A, var release: F) -> ResourceFactory[A, _NativeBorrow[T, R, X, F, True]] where T == A.Value and R.Error == A.Error and _ErrorCompatible[A.Error, X]:
    """Adapt a raising native release factory through the same cleanup owner."""
    return resource(acquire^, _NativeBorrow[T, R, X, F, True](release^))
