"""Compositional acquisition plans interpreted by the shared resumable Scope.

Resource erases one of these plans; composition joins them without erasure.
"""
from std.builtin.rebind import downcast, rebind_var
from std.os import abort
from fp.callables.protocols import BorrowCallContract, BorrowOnceCallable
from fp.callables._binding import _BorrowThunk
from fp.callables._receiver import _OnceBorrowAvailable, _borrow_once_as
from fp._internal.errors import _ErrorCompatible
from fp.effects import IOContext
from fp.effects.outcomes import _capture, _failure_as
from .kernel import Machine, Step, Wait, _Slot, _tick
from .scopes import ScopedMachine, CleanupMachine, Scope
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
    """The bound for a resource acquisition plan.

    Resource constructors and composition supply plans; Resource owns their
    execution. No independent release operation is part of this contract.
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


def _acquire_release[A: Machine, C: ScopedMachine](var acquire: A, var release: C) -> _Acquire[A, _ScopedCleanup[C, False, True]]:
    # The plan of a resource with scoped release; public constructors admit inputs.
    comptime assert A.Value == C.Input and A.Error == C.Error
    return _Acquire(acquire^, _ScopedCleanup[C, False, True](release^))
