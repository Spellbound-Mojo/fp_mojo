"""Supervisor: a scope whose own fiber owns supervised fibers until the scope ends.

`Supervisor[E].scoped(body)` starts a parked supervisor fiber owned by the
calling run loop, runs the body with the supervisor, and releases it as a
finalizer, all on the caller's run loop. `supervise(io)` starts `io` with the
supervisor fiber's scope as its owner, so a supervised fiber can outlive the
program that started it. Release stops the parked program; the supervisor
fiber's task then cancels the live supervised fibers and waits for them, as any
owner drains its children, or, when the supervisor awaits on release, release
first waits for them to finish.
"""
from std.memory import ArcPointer
from std.os import abort
from fp._internal.erased import _Erased
from fp._internal.waking import _Event as Signal
from std.builtin.rebind import downcast
from fp.callables.protocols import UnaryContract, OnceUnary
from fp.callables.native import NativeUnary, _NativeOwnedArg
from fp.effects import IOContext
from .kernel import Machine, Step, Wait
from .fibers import _FiberRecord, _Scope as _FiberScope, _unit
from .engine import IO, Fiber, _Program, _Head, _DEFER, _Binds, _loop_at, _RunLoop


struct _Stop(Movable):
    """The request that ends a supervisor fiber's parked program."""
    var requested: Bool
    var signal: Signal

    def __init__(out self):
        self.requested = False
        self.signal = Signal()


@fieldwise_init
struct _Parked[E: Movable & Deinitable](Machine):
    """The supervisor fiber's own program: wait until release stops it."""
    comptime Value = NoneType
    comptime Error = Self.E
    var stop: ArcPointer[_Stop]

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        var revision = self.stop[].signal.revision()
        if self.stop[].requested:
            return _unit[Self.E]()
        if context.canceled():
            return Step[NoneType, Self.E].ready(None)
        return Step[NoneType, Self.E].pending(Wait.changed(self.stop[].signal, revision))


@fieldwise_init
struct _SupervisorState[E: Movable & Deinitable](Movable):
    # The supervisor fiber's scope: the owner of every supervised fiber.
    var scope: ArcPointer[_FiberScope[Self.E]]
    var fiber: Fiber[NoneType, Self.E]
    var children: List[ArcPointer[_FiberRecord[Self.E]]]
    var stop: ArcPointer[_Stop]
    var stopping: Bool
    var await_on_release: Bool


@fieldwise_init
struct _Supervised[E: Movable & Deinitable](Movable):
    var program: _Program[Self.E]
    var state: ArcPointer[_SupervisorState[Self.E]]

    def start(deinit self, mut run: _RunLoop[Self.E]) -> ArcPointer[_FiberRecord[Self.E]]:
        """Start the program from the calling run loop, owned by the supervisor fiber."""
        ref state = self.state[]
        if state.stopping:
            abort("a supervisor cannot start fibers after its release")
        var live = List[ArcPointer[_FiberRecord[Self.E]]]()
        for index in range(len(state.children)):
            if not state.children[index][].done:
                live.append(state.children[index].copy())
        var record = ArcPointer(_FiberRecord[Self.E]())
        _ = run.spawn(self.program^, record.copy(), Optional(state.scope.copy()))
        live.append(record.copy())
        state.children = live^
        return record^


struct Supervisor[E: Movable & Deinitable](Copyable):
    """Owns fibers beyond the program that starts them, until its scope ends.

    The counterpart of Cats Effect's Supervisor. Run a body with one through
    `Supervisor[E].scoped(body)` and start fibers with `supervise`. When the
    body ends, release cancels the supervised fibers that are still live and
    waits for them; with `await_on_release`, it waits for them to finish
    instead. Copies share one supervisor. Supervising after release is a
    protocol violation.

    Parameters:
        E: The domain error shared with the supervised fibers.
    """
    var _state: ArcPointer[_SupervisorState[Self.E]]

    def __init__(out self, *, var _state: ArcPointer[_SupervisorState[Self.E]]):
        self._state = _state^

    @staticmethod
    def scoped[F: UnaryContract & Movable & Deinitable](var body: F, await_on_release: Bool = False) -> IO[downcast[F.Out, Machine].Value, Self.E] where F.Arg == Supervisor[Self.E] and _Binds[Self.E, F]:
        """Run a body with a supervisor that is released when the body ends.

        The counterpart of Cats Effect's Supervisor(...).use. Release runs as a
        masked finalizer on every exit: it cancels the supervised fibers that
        are still live and waits for them, or with await_on_release waits for
        them to finish.

        Parameters:
            F: An owned once-callable from Supervisor[E] to an IO with error E.

        Args:
            body: The body, consumed; it runs once, with the supervisor.
            await_on_release: Wait for live supervised fibers to finish on
                release instead of canceling them.

        Returns:
            An IO with the body's outcome, completing after release.
        """
        return _acquire[Self.E](await_on_release)._bind(_Scope[F, Self.E](body^))

    @staticmethod
    def scoped[U: Movable & Deinitable, //](body: def(var _NativeOwnedArg[Supervisor[Self.E]]) thin -> IO[U, Self.E], await_on_release: Bool = False) -> IO[U, Self.E]:
        """Run a native body with a supervisor that is released when it ends."""
        return Self.scoped(NativeUnary[Supervisor[Self.E], IO[U, Self.E], Never, def(var _NativeOwnedArg[Supervisor[Self.E]]) thin -> IO[U, Self.E], False](body), await_on_release)

    def supervise[T: Movable & Deinitable](self, var program: IO[T, Self.E]) -> IO[Fiber[T, Self.E], Self.E]:
        """Start a program as a fiber owned by this supervisor.

        The fiber is not drained when the program that started it finishes; it
        runs until it completes, is canceled, or the supervisor is released.
        Starting observes cancellation, like start.

        Parameters:
            T: The program's success type.

        Args:
            program: The program, consumed.

        Returns:
            An IO producing the fiber's handle.
        """
        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            ref run = _loop_at[Self.E](loop)
            var record = callable^.take[_Supervised[Self.E]]().start(run)
            run.set_value(_Erased(Fiber[T, Self.E](_record=record^)))

        var parts = _Supervised[Self.E](program^._into_program(), self._state.copy())
        return IO[Fiber[T, Self.E], Self.E](_program=_Program[Self.E](_Head[Self.E](_DEFER, _Erased(parts^), invoke)))


def _acquire[E: Movable & Deinitable](await_on_release: Bool) -> IO[Supervisor[E], E]:
    """Start the parked supervisor fiber in the running fiber's host."""
    def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
        ref run = _loop_at[E](loop)
        var awaits = callable^.take[Bool]()
        var stop = ArcPointer(_Stop())
        var record = ArcPointer(_FiberRecord[E]())
        var scope = run.spawn(IO[NoneType, E]._lifted(_Parked[E](stop.copy()))._into_program(), record.copy())
        var state = _SupervisorState[E](scope^, Fiber[NoneType, E](_record=record^), List[ArcPointer[_FiberRecord[E]]](), stop^, False, awaits)
        run.set_value(_Erased(Supervisor[E](_state=ArcPointer(state^))))

    return IO[Supervisor[E], E](_program=_Program[E](_Head[E](_DEFER, _Erased(await_on_release), invoke)))


@fieldwise_init
struct _Scope[F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    """Run the body with the acquired supervisor; release it as the body's finalizer."""
    var body: Self.F
    comptime Arg = Supervisor[Self.E]
    comptime Out = IO[downcast[Self.F.Out, Machine].Value, Self.E]

    def call_once(deinit self, var supervisor: Supervisor[Self.E]) -> Self.Out:
        var release = _release[Self.E](supervisor)
        return IO[Supervisor[Self.E], Self.E].pure(supervisor^)._bind(self.body^).guarantee(release^)


def _release[E: Movable & Deinitable](supervisor: Supervisor[E]) -> IO[NoneType, E]:
    return IO[NoneType, E]._lifted(_Release[E](supervisor._state.copy()))


@fieldwise_init
struct _Release[E: Movable & Deinitable](Machine):
    """Stop the supervisor, then wait until it and its fibers have finished."""
    comptime Value = NoneType
    comptime Error = Self.E
    var state: ArcPointer[_SupervisorState[Self.E]]

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        ref state = self.state[]
        if not state.stopping:
            if state.await_on_release:
                var wait = Wait.never()
                wait._interruptible = False
                var live = False
                for index in range(len(state.children)):
                    ref child = state.children[index][]
                    var revision = child.signal.revision()
                    if not child.done:
                        live = True
                        var each = Wait.changed(child.signal, revision)
                        each._interruptible = False
                        wait._include(each, context)
                if live:
                    return Step[NoneType, Self.E].pending(wait^)
            state.stopping = True
            state.stop[].requested = True
            state.stop[].signal.notify()
        ref supervisor = state.fiber._claim.record[]
        var revision = supervisor.signal.revision()
        if supervisor.done:
            return _unit[Self.E]()
        var wait = Wait.changed(supervisor.signal, revision)
        wait._interruptible = False
        return Step[NoneType, Self.E].pending(wait^)
