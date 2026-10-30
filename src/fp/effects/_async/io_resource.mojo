"""Resource[T, E]: an acquisition plan of hidden type, used through IO and the canonical Scope.

A resource erases its typed plan once, at construction. Each use erases its
scoped body to one carrier per resource type and runs the plan's Scope as an
IO leaf; the body's value is boxed by that carrier and unboxed by the same use.
Composition reuses the typed plan owners: flat_map joins this resource as the
left plan of the canonical join.
"""
from std.builtin.rebind import downcast, rebind_var
from fp.callables.protocols import BorrowCallContract
from fp.callables.invoke import _OnceBorrowAvailable
from fp.callables.native import NativeBorrow
from fp._internal.erased import _Erased
from fp._internal.errors import _ErrorCompatible
from fp.effects import IOContext
from fp.effects.resources import _MapScopeFactory
from .kernel import Machine, Step
from .scopes import ScopedMachine, CleanupMachine
from .resources import ResourcePlan, _AsyncResourceType, _Acquire, _Join, _ScopedBuild, _PureFactory, _acquire_release
from .engine import IO, _IsIO, _Admitted, _box_step, _Unbox


comptime _ScopedPoll[T: Movable & Deinitable, E: Movable & Deinitable] = def(mut _Erased, T, IOContext[E]) thin -> Step[_Erased, E]


struct _ErasedScoped[T: Movable & Deinitable, E: Movable & Deinitable](ScopedMachine):
    """Poll a scoped body of hidden type under the scope's loan, boxing its value."""
    comptime Input = Self.T
    comptime Value = _Erased
    comptime Error = Self.E
    var _body: _Erased
    var _poll: _ScopedPoll[Self.T, Self.E]

    def __init__[U: ScopedMachine](out self, var body: U):
        def poll(mut body: _Erased, value: Self.T, context: IOContext[Self.E]) -> Step[_Erased, Self.E]:
            comptime assert U.Input == Self.T and U.Error == Self.E
            return _box_step(rebind_var[Step[U.Value, Self.E]](body.pointer[U]()[].poll(rebind[U.Input](value), rebind[IOContext[U.Error]](context))))

        comptime assert U.Input == Self.T and U.Error == Self.E
        self._body = _Erased(body^)
        self._poll = poll

    def poll[p: ImmOrigin](mut self, ref[p] value: Self.T, context: IOContext[Self.E]) -> Step[_Erased, Self.E]:
        return self._poll(self._body, value, context)


comptime _UsePlan[T: Movable & Deinitable, E: Movable & Deinitable] = def(var _Erased, var _ErasedScoped[T, E]) thin -> IO[_Erased, E]

# A body or release factory borrows the resource and returns an IO with the
# resource's error; the IO cannot retain the loan.
comptime _Factory[T: Movable & Deinitable, E: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = F.Payload == T and _OnceBorrowAvailable[F] and _ErrorCompatible[E, F.Failure] and _Admitted[F]
comptime _Joins[E: Movable & Deinitable, R: AnyType] = (downcast[R, _AsyncResourceType].Plan.Error == E) if conforms_to(R, _AsyncResourceType) else False


struct Resource[T: Movable & Deinitable, E: Movable & Deinitable](ResourcePlan, _AsyncResourceType):
    """A resource acquired before and released after each use, as an IO.

    `use` acquires masked, lends the resource to a body factory, runs the IO it
    builds, then releases masked with the exact exit. Releases run in reverse
    acquisition order and their errors follow the body's. Bodies and release
    factories borrow the resource and cannot retain it in the IO they return.

    Parameters:
        T: The owned resource value, lent during use.
        E: The exact domain error of acquisition, use and release.
    """
    comptime Value = Self.T
    comptime Error = Self.E
    comptime Plan = Self
    comptime _Used[U: ScopedMachine] = IO[U.Value, Self.E]
    var _plan: _Erased
    var _use_plan: _UsePlan[Self.T, Self.E]

    def __init__[P: ResourcePlan](out self, var plan: P):
        """Erase a typed plan; its type fixes every later cast of the box."""
        def use_plan(var plan: _Erased, var body: _ErasedScoped[Self.T, Self.E]) -> IO[_Erased, Self.E]:
            comptime assert P.Value == Self.T and P.Error == Self.E
            return IO[_Erased, Self.E]._lifted(plan^.take[P]()._use(body^))

        comptime assert P.Value == Self.T and P.Error == Self.E
        self._plan = _Erased(plan^)
        self._use_plan = use_plan

    def __init__(out self, *, var _plan: _Erased, _use_plan: _UsePlan[Self.T, Self.E]):
        self._plan = _plan^
        self._use_plan = _use_plan

    def _into_plan(deinit self) -> Self:
        return Self(_plan=self._plan^, _use_plan=self._use_plan)

    def _use[U: ScopedMachine](deinit self, var body: U) -> IO[U.Value, Self.E]:
        var boxed = self._use_plan(self._plan^, _ErasedScoped[Self.T, Self.E](body^))
        return boxed^._mapped(_Unbox[U.Value]())

    @staticmethod
    def make[F: BorrowCallContract & Movable & Deinitable](var acquire: IO[Self.T, Self.E], var release: F) -> Self where _Factory[Self.T, Self.E, F] and _IsIO[F.Result, Self.E] and downcast[F.Result, Machine].Value == NoneType:
        """Acquire with an IO; release with the IO a factory builds from the borrowed resource.

        Parameters:
            F: A once-admitted owned factory borrowing T and returning IO[NoneType, E].

        Args:
            acquire: The acquisition, run masked.
            release: The release factory, run masked after each use.

        Returns:
            An unopened resource; a failed acquisition runs no release.
        """
        return Self(_acquire_release(acquire^, _ScopedBuild[F, Self.E](release^)))

    @staticmethod
    def make(var acquire: IO[Self.T, Self.E], release: def(Self.T) thin -> IO[NoneType, Self.E]) -> Self:
        """Acquire with an IO; release with a native function of the borrowed resource."""
        return Self.make(acquire^, NativeBorrow[Self.T, IO[NoneType, Self.E], Never, def(Self.T) thin -> IO[NoneType, Self.E], False](release))

    @staticmethod
    def make_case[C: CleanupMachine](var acquire: IO[Self.T, Self.E], var release: C) -> Self where C.Input == Self.T and C.Error == Self.E:
        """Acquire with an IO; release with a machine that sees the exact exit.

        The Cats Effect counterpart is Resource.makeCase. The release borrows
        the resource and the body's ExitCase on each poll and may suspend.

        Parameters:
            C: A cleanup machine borrowing T, with error E.

        Args:
            acquire: The acquisition, run masked.
            release: The release, run masked after each use.

        Returns:
            An unopened resource; a failed acquisition runs no release.
        """
        return Self(_Acquire(acquire^, release^))

    @staticmethod
    def pure(var value: Self.T) -> Self:
        """Own a value as a resource with nothing to release."""
        return Self(_PureFactory[Self.T, Self.E]().call(value^)._into_plan())

    def use[F: BorrowCallContract & Movable & Deinitable](deinit self, var body: F) -> IO[downcast[F.Result, Machine].Value, Self.E] where _Factory[Self.T, Self.E, F] and _IsIO[F.Result, Self.E]:
        """Acquire, build the body's IO from the borrowed resource, run it, then release.

        Parameters:
            F: A once-admitted owned factory borrowing T and returning an IO.

        Args:
            body: The factory, called once after acquisition.

        Returns:
            An IO owning acquisition, body and release; release errors follow body errors.
        """
        return self^._use(_ScopedBuild[F, Self.E](body^))

    def use_scoped[U: ScopedMachine](deinit self, var body: U) -> IO[U.Value, Self.E] where U.Input == Self.T and U.Error == Self.E:
        """Acquire, poll a body with a fresh loan of the resource each poll, then release.

        Use this when work that suspends must keep using a move-only resource:
        an IO built by use cannot retain the resource across suspensions.

        Parameters:
            U: A scoped machine borrowing T, with error E.

        Args:
            body: The body, polled until it completes.

        Returns:
            An IO owning acquisition, body and release; release errors follow body errors.
        """
        return self^._use(body^)

    def use[U: Movable & Deinitable, //](deinit self, body: def(Self.T) thin -> IO[U, Self.E]) -> IO[U, Self.E]:
        """Use the resource through a native function."""
        return self^.use(NativeBorrow[Self.T, IO[U, Self.E], Never, def(Self.T) thin -> IO[U, Self.E], False](body))

    def flat_map[F: BorrowCallContract & Movable & Deinitable](deinit self, var f: F) -> Resource[downcast[F.Result, _AsyncResourceType].Plan.Value, Self.E] where _Factory[Self.T, Self.E, F] and _Joins[Self.E, F.Result]:
        """Acquire a dependent resource from the borrowed one; release it first.

        Parameters:
            F: A once-admitted owned factory borrowing T and returning a Resource.

        Args:
            f: The factory, called after this resource's acquisition.

        Returns:
            A resource exposing the dependent value while owning both releases.
        """
        return self^._joined(f^)

    def flat_map[U: Movable & Deinitable, //](deinit self, f: def(Self.T) thin -> Resource[U, Self.E]) -> Resource[U, Self.E]:
        """Acquire a dependent resource through a native function."""
        return self^._joined(NativeBorrow[Self.T, Resource[U, Self.E], Never, def(Self.T) thin -> Resource[U, Self.E], False](f))

    def _joined[F: BorrowCallContract & Movable & Deinitable](deinit self, var f: F) -> Resource[downcast[F.Result, _AsyncResourceType].Plan.Value, Self.E]:
        comptime assert _Factory[Self.T, Self.E, F] and _Joins[Self.E, F.Result]
        return Resource[downcast[F.Result, _AsyncResourceType].Plan.Value, Self.E](_Join(self^, f^))

    def map[F: BorrowCallContract & Movable & Deinitable](deinit self, var f: F) -> Resource[F.Result, Self.E] where _Factory[Self.T, Self.E, F]:
        """Project an owned value from the borrowed resource, keeping its release.

        Parameters:
            F: A once-admitted owned projection borrowing T.

        Args:
            f: The projection, called after acquisition.

        Returns:
            A resource of the projected value; the projection cannot retain the loan.
        """
        return rebind_var[Resource[F.Result, Self.E]](self^._joined(_MapScopeFactory[F, Self.E, _PureFactory[F.Result, Self.E]](f^)))

    def map[R: Movable & Deinitable, //](deinit self, f: def(Self.T) thin -> R) -> Resource[R, Self.E]:
        """Project an owned value through a native function."""
        return self^.map(NativeBorrow[Self.T, R, Never, def(Self.T) thin -> R, False](f))
