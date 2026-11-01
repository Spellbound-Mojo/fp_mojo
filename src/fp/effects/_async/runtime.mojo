"""The public `Runtime`: workers that run many programs, shared by its copies.

After Cats Effect's `IORuntime`, with an explicit value instead of a global.
A runtime is created from `IORuntimeConfig`; its profile decides where
programs run:

- **Current-thread profile.** No thread starts. `run` drives the root on the
  calling thread through the free `run`'s loop (`kernel._drive`).
- **Work-stealing profile.** Every worker of a `_Pool` starts when the runtime
  is created (`_Pool.start_all`). `run` submits the root to the pool
  (`_submit_root`) and parks the caller in its own poller until the root
  completes (`_RootHandle.wait`), as Cats Effect's `unsafeRunSync` blocks.
  Calling it on one of the runtime's own workers aborts: it would block a
  worker the program may need (`_on_own_thread`).

Ownership. Copies hold one `ArcPointer` to a `_RuntimeCore`, as copies of a
`BlockingPool` hold its owner, and there is no `close()`. The core's
destructor, which runs when the last copy is dropped, is the shutdown:

1. Cancel and drain: request cancellation of every live root and wait until
   none is registered. Today this finds nothing. Every caller of `run`
   borrows a copy for the whole call and there is no fire-and-forget call,
   so the last copy can only be dropped once every `run` returned, and a
   root completes only after its fibers. The step keeps the contract for a
   later fire-and-forget call.
2. `_Pool.shutdown`: stop and join every worker. Each leaving worker drops
   the entries left on its ring on its own thread (`drain_on_shutdown`), then
   the external queue is emptied.
3. On one of the runtime's own workers, which cannot join itself, as when a
   finished root's program state held the last copy and is destroyed on a
   worker: `_Pool.shutdown_on_worker` joins the others, detaches this
   worker's thread and hands it the pool's last reference, which the thread
   drops after its loop.

Live roots. `run` registers each root with a number, from 1 in submission
order, its scheduler and its token, in a list behind the shared spin lock
(`_Cell`); the lock is held only to add, remove or copy entries. Each root's
fiber table is created shared (`_FiberSlots.share_snapshots`), so `fibers()`
may snapshot it from any thread while the root's fibers run and finish.

Every method takes immutable `self`, and the core is reached from any thread
that holds a copy; its mutable state lives behind the cell's lock and the
pool's own allocations (the development guide's "Never borrow a shared object
mutably from two threads").
"""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.builtin.rebind import rebind_var
from std.os import abort
from std.time import sleep
from fp._internal.cells import _Cell, _lock_metadata
from fp._internal.erased import _Erased
from fp._internal.os import OSError
from fp._internal.thread_safety import ThreadTransferable
from fp._internal.waking import _Clock, _Scheduler
from fp.effects import CancellationToken, Outcome
from .fibers import FiberInfo, _append_fiber_infos
from .profile import Profile
from .kernel import IORuntimeConfig, Machine, Driver as _Driver, _drive
from .pool import _Pool, _RootSink, _on_own_thread, _release_root, _root_scheduler, _queue_root, _RootResult, _Waited, _RootHandle
from .scheduling.blocking_pool import BlockingPool, _Calls, _Job, _WorkerContext


struct _LiveRoot(Copyable):
    """A root running on a runtime: its number, its scheduler and its token."""
    var number: Int
    var scheduler: ArcPointer[_Scheduler]
    var token: CancellationToken

    def __init__(out self, number: Int, scheduler: ArcPointer[_Scheduler], token: CancellationToken):
        self.number = number
        self.scheduler = scheduler.copy()
        self.token = token.copy()


struct _Roots(Movable):
    """The live roots, behind the core's lock, and the next root's number."""
    var next: Int
    var live: List[_LiveRoot]

    def __init__(out self):
        self.next = 1
        self.live = List[_LiveRoot]()


struct _RuntimeCore(Movable):
    """What every copy of a `Runtime` shares; its destructor is the shutdown (module docstring)."""
    var config: IORuntimeConfig
    var profile: Profile
    var pool: Optional[ArcPointer[_Pool]]
    var roots: ArcPointer[_Cell[_Roots]]
    # A current-thread runtime's threads for `eval_on` regions: the configured
    # blocking pool, or a private one, which starts no thread until a region.
    var regions: Optional[BlockingPool]

    def __init__(out self, config: IORuntimeConfig) raises OSError:
        self.config = config.copy()
        self.roots = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_Roots())))
        self.pool = None
        self.regions = None
        # Resolved once: the default reads the processor count (`Profile._concrete`).
        var profile = config.profile._concrete()
        self.profile = profile.copy()
        if not profile.is_work_stealing():
            if config.blocking_pool:
                self.regions = Optional(config.blocking_pool.value().copy())
            else:
                try:
                    self.regions = Optional(BlockingPool())
                except:
                    abort("fp.effects: the default blocking pool configuration is invalid")
        if profile.is_work_stealing():
            # Per pool, since a runtime's roots share one thread cache for
            # the blocking hand-off.
            var pool = ArcPointer(_Pool(profile.workers(), 0, max_blocking_threads=config.max_blocking_threads, blocking_idle_timeout=config.blocking_idle_timeout))
            try:
                pool[].start_all(Int(Pointer(to=pool[])))
            except error:
                pool[].shutdown()
                raise error^
            self.pool = Optional(pool^)

    def __deinit__(deinit self):
        self._cancel_and_drain()
        if self.pool:
            var pool = self.pool.take()
            var index = _on_own_thread(pool[])
            if index >= 0:
                pool[].shutdown_on_worker(pool.copy(), index)
            else:
                pool[].shutdown()
            # On a worker, the detached thread now holds the last reference.
            _ = pool^
        # A region thread may drop the last copy: the pool then closes on it.
        _ = self.regions^
        _ = self.roots^

    def _cancel_and_drain(self):
        """Cancel every live root and wait until none remains (module docstring, step 1)."""
        for root in self.live():
            root.token.cancel()
        while True:
            var guard = _lock_metadata(self.roots)
            var remaining = len(guard.cell[].slot.value().live)
            _ = guard^
            if remaining == 0:
                return
            sleep(0.001)

    def register(self, scheduler: ArcPointer[_Scheduler], token: CancellationToken) -> Int:
        """Add a live root; returns its number."""
        var guard = _lock_metadata(self.roots)
        ref roots = guard.cell[].slot.value()
        var number = roots.next
        roots.next += 1
        roots.live.append(_LiveRoot(number, scheduler, token))
        _ = guard^
        return number

    def unregister(self, number: Int):
        """Remove a root that completed; its entry is dropped outside the lock."""
        var removed: Optional[_LiveRoot] = None
        var guard = _lock_metadata(self.roots)
        ref live = guard.cell[].slot.value().live
        for i in range(len(live)):
            if live[i].number == number:
                removed = Optional(live.pop(i))
                break
        _ = guard^
        _ = removed^

    def live(self) -> List[_LiveRoot]:
        """A copy of the live roots, taken under the lock."""
        var guard = _lock_metadata(self.roots)
        var copy = guard.cell[].slot.value().live.copy()
        _ = guard^
        return copy^


struct Runtime(Copyable, ThreadTransferable):
    """Runs programs on the threads its profile asks for; copies share one runtime.

    The counterpart of Cats Effect's `IORuntime`, as an explicit value: there
    is no global runtime. With `Profile.work_stealing(n)`, the default with
    one worker per logical processor (the current-thread profile on a
    one-processor host), the runtime starts `n` worker threads
    when it is created, and every `run` executes its program on them while
    the caller waits. With `Profile.current_thread()`, each `run` runs its
    program on the calling thread, as the free `run` does. Long-running
    applications create one runtime and run many programs on it, from any
    number of threads.

    There is no `close()`. When the last copy is dropped, the runtime cancels
    the fibers still running, waits for them to finish, and joins its
    threads. Every `run` holds a copy until it returns, so in practice the
    last copy goes once every program completed. If the last copy is dropped
    on one of the runtime's own workers, for example by a program that held
    one, that worker cannot join itself: it finishes its current work and
    exits on its own, releasing the runtime last.
    """
    var _core: ArcPointer[_RuntimeCore]

    def __init__(out self, config: IORuntimeConfig = IORuntimeConfig()) raises OSError:
        """Create a runtime and start the workers its configuration's profile asks for.

        Args:
            config: The profile, and the interpreter settings every program
                run on this runtime uses.

        Raises:
            OSError: A worker thread could not be started; the ones already
                started are stopped and joined.
        """
        self._core = ArcPointer(_RuntimeCore(config))

    def run[P: Machine](self, var program: P) -> Outcome[P.Value, P.Error]:
        """Run a program with a fresh cancellation token and wait for its outcome.

        Parameters:
            P: The exact machine type and its native origins.

        Args:
            program: The unopened program, consumed once.

        Returns:
            The owned terminal outcome, after the program's fibers and cleanup
            finished.
        """
        return self.run(program^, CancellationToken())

    def run[P: Machine](self, var program: P, token: CancellationToken) -> Outcome[P.Value, P.Error]:
        """Run a program under a token and wait for its outcome.

        On the work-stealing profile the program runs on the runtime's workers
        and the calling thread parks until it completes. Calling this on one
        of the runtime's own workers aborts, since it would block a worker the
        program may need: inside a program, use `start` and `join`. Another
        runtime's worker, or a blocking thread, may call it and blocks. On the
        current-thread profile the program runs on the calling thread.

        Parameters:
            P: The exact machine type and its native origins.

        Args:
            program: The unopened program, consumed once.
            token: Shared cancellation requests; requests do not themselves join.

        Returns:
            The owned terminal outcome, after the program's fibers and cleanup
            finished.
        """
        ref core = self._core[]
        if not core.pool:
            return _drive_here(program^, token, core.config, ExecutionContext(self), Optional(self.copy()))
        ref pool = core.pool.value()
        if _on_own_thread(pool[]) >= 0:
            abort("fp.effects: Runtime.run was called on one of the runtime's own workers, which its program may need; inside a program, use start and join")
        var scheduler = self._prepare_root(token)
        var number = scheduler[1]
        var result = ArcPointer(_RootResult[P.Value, P.Error]())
        _queue_root(scheduler[0], program^, token, core.config, _Waited[P.Value, P.Error](result.copy()))
        var handle = _RootHandle[P.Value, P.Error](result^, scheduler[0].copy())
        try:
            handle.wait(pool[])
        except error:
            abort(String("fp.effects: Runtime.run could not wait for its program: ", error))
        core.unregister(number)
        return handle^.take()

    def _prepare_root(self, token: CancellationToken) -> Tuple[ArcPointer[_Scheduler], Int]:
        """A pool root's scheduler, shared for `fibers()`, registered and given this runtime as its context.

        Registration comes before the root is queued, so a root that completes
        at once is never left registered.
        """
        ref core = self._core[]
        var scheduler = _root_scheduler(core.pool.value(), True)
        var number = core.register(scheduler, token)
        scheduler[].set_context(_Erased(ExecutionContext(self)))
        return (scheduler^, number)

    def _start_region[P: Machine, D: _RegionEnd](self, var program: P, token: CancellationToken, var end: D):
        """Run `program` as a root of this runtime that nobody waits for; its outcome goes to `end`.

        `IO.eval_on`'s region (`contexts.mojo`). On the work-stealing profile
        the root is detached (`_DetachedRoot`); on the current-thread profile it
        is driven on one of the runtime's region threads (`_start_on_thread`).
        Either way it holds a copy of this runtime until it finished.
        """
        comptime assert D.Value == P.Value and D.Error == P.Error
        ref core = self._core[]
        if not core.pool:
            _start_on_thread(core.regions.value(), program^, token, core.config, ExecutionContext(self), Optional(self.copy()), end^)
            return
        var scheduler = self._prepare_root(token)
        _queue_root(scheduler[0], program^, token, core.config, _DetachedRoot[D](self.copy(), scheduler[1], end^))

    def fibers(self) -> List[FiberInfo]:
        """List the live fibers of every program running on this runtime.

        A bounded diagnostic view, like Cats Effect's fiber dump, with
        `Driver.fibers()`'s contract: no payloads and no completed fibers.
        Each entry's `root` numbers its program on this runtime, from 1 in
        submission order, and its `index` and `owner` name slots of that
        program's fiber table. It may be called from any thread at any time;
        while fibers run in parallel, each is listed as it stood at some moment
        during the call.

        Returns:
            The live fibers, grouped by program in submission order, then in
            slot order.
        """
        var fibers = List[FiberInfo]()
        for root in self._core[].live():
            _append_fiber_infos(fibers, root.scheduler[].snapshot(), root.number)
        return fibers^


struct ExecutionContext(Copyable, Equatable, ThreadTransferable, Writable):
    """Where `IO.eval_on` runs a program: a `Runtime` or a `BlockingPool`.

    The counterpart of the `ExecutionContext` Cats Effect's `evalOn` takes.
    It converts implicitly from either target, so `io.eval_on(runtime)` and
    `io.eval_on(pool)` both read naturally, and `IO.execution_context()`
    returns the one running the current program. Copies refer to the same
    target, which they keep alive: a context holding a runtime's last copy
    keeps that runtime's threads running.

    Two contexts are equal when they refer to the same shared target, as two
    copies of one `Runtime` or of one `BlockingPool` do.
    """
    var _runtime: Optional[Runtime]
    var _pool: Optional[BlockingPool]

    @implicit
    def __init__(out self, runtime: Runtime):
        """Target a runtime: a region runs as one of its programs.

        Args:
            runtime: The runtime, copied.
        """
        self._runtime = Optional(runtime.copy())
        self._pool = None

    @implicit
    def __init__(out self, pool: BlockingPool):
        """Target a blocking pool: a region runs on one of its threads, for its whole length.

        Args:
            pool: The pool, copied.
        """
        self._runtime = None
        self._pool = Optional(pool.copy())

    def runtime(self) -> Optional[Runtime]:
        """The targeted runtime, if this context is one.

        Returns:
            A copy of the runtime, or None for a blocking pool.
        """
        if self._runtime:
            return Optional(self._runtime.value().copy())
        return None

    def blocking_pool(self) -> Optional[BlockingPool]:
        """The targeted blocking pool, if this context is one.

        Returns:
            A copy of the pool, or None for a runtime.
        """
        if self._pool:
            return Optional(self._pool.value().copy())
        return None

    def _address(self) -> Int:
        if self._runtime:
            return Int(Pointer(to=self._runtime.value()._core[]))
        return Int(Pointer(to=self._pool.value()._owner[]))

    def __eq__(self, other: Self) -> Bool:
        """Whether both contexts refer to the same runtime or the same pool.

        Args:
            other: The other context.

        Returns:
            True for the same shared target.
        """
        return Bool(self._runtime) == Bool(other._runtime) and self._address() == other._address()

    def write_to(self, mut writer: Some[Writer]):
        """Write `runtime(current_thread)`, `runtime(work_stealing(n))` or `blocking_pool`.

        Args:
            writer: The destination.
        """
        if self._runtime:
            writer.write("runtime(", self._runtime.value()._core[].profile, ")")
        else:
            writer.write("blocking_pool")


# ===------------------------------------------------------------------=== #
# Regions: roots nobody waits for (`IO.eval_on`, `contexts.mojo`)
# ===------------------------------------------------------------------=== #


trait _RegionEnd(Movable, Deinitable):
    """What receives a region's outcome, once, on the thread that finished its root.

    It runs after the root was released and its target's copy dropped, so the
    caller that it resumes finds the target as the region left it.
    """
    comptime Value: Movable & Deinitable
    comptime Error: Movable & Deinitable

    def finish(deinit self, var outcome: Outcome[Self.Value, Self.Error]):
        """Deliver the region's outcome."""
        ...


struct _DetachedRoot[D: _RegionEnd](_RootSink):
    """The sink of a region's root on a work-stealing runtime: the pool takes its own handle.

    On the worker that finishes the root, in this order: release the root
    (`_release_root`, as `_RootHandle.take` does for a waiting caller),
    unregister it, drop the region's copy of the runtime, then deliver the
    outcome. The region holds that copy from submission, and unregisters
    before dropping it, so the runtime's last copy is never dropped while a
    registered root is live: `_cancel_and_drain` finds none, and a last copy
    dropped here, on the runtime's own worker, takes `shutdown_on_worker`'s
    path (step 3 of the shutdown above).
    """
    comptime Value = Self.D.Value
    comptime Error = Self.D.Error
    var runtime: Optional[Runtime]
    var number: Int
    var end: Optional[Self.D]

    def __init__(out self, var runtime: Runtime, number: Int, var end: Self.D):
        self.runtime = Optional(runtime^)
        self.number = number
        self.end = Optional(end^)

    def complete(mut self, var outcome: Outcome[Self.Value, Self.Error], scheduler: ArcPointer[_Scheduler]):
        _release_root(scheduler)
        var runtime = self.runtime.take()
        runtime._core[].unregister(self.number)
        # Possibly the last copy: the runtime then shuts down from this worker.
        _ = runtime^
        self.end.take().finish(outcome^)


def _drive_here[P: Machine](var program: P, token: CancellationToken, config: IORuntimeConfig, context: ExecutionContext, runtime: Optional[Runtime]) -> Outcome[P.Value, P.Error]:
    """Drive `program` as a current-thread root on the calling thread, with `context` as its execution context.

    The one path for `Runtime.run` on the current-thread profile and for a
    region on a blocking thread. A runtime's root is registered for
    `fibers()` and cancel-and-drain while it runs.
    """
    var driver = _Driver(program^, token, _Clock(), config)
    var scheduler = driver.task._executor.scheduler.copy()
    var number = 0
    if runtime:
        scheduler[].share_snapshots()
        number = runtime.value()._core[].register(scheduler, token)
    scheduler[].set_context(_Erased(context.copy()))
    var outcome = _drive(driver^)
    if runtime:
        runtime.value()._core[].unregister(number)
    return outcome^


struct _ThreadRegion[P: Machine, D: _RegionEnd](Movable):
    """A region driven as a current-thread root on one blocking thread, for its whole length."""
    var program: Self.P
    var token: CancellationToken
    var config: IORuntimeConfig
    var context: ExecutionContext
    var runtime: Optional[Runtime]
    var end: Self.D

    def __init__(out self, var program: Self.P, token: CancellationToken, config: IORuntimeConfig, var context: ExecutionContext, var runtime: Optional[Runtime], var end: Self.D):
        self.program = program^
        self.token = token.copy()
        self.config = config.copy()
        self.context = context^
        self.runtime = runtime^
        self.end = end^

    def run(deinit self):
        """Drive the region on this thread, drop the target's copies, then deliver the outcome."""
        comptime assert Self.D.Value == Self.P.Value and Self.D.Error == Self.P.Error
        var outcome = _drive_here(self.program^, self.token, self.config, self.context, self.runtime.copy())
        # Drop the target's copies before resuming the caller; a last copy of a
        # runtime or a pool closes it from this thread (`BlockingPool`'s rule).
        _ = self.context^
        _ = self.runtime^
        self.end^.finish(rebind_var[Outcome[Self.D.Value, Self.D.Error]](outcome^))


def _run_thread_region[P: Machine, D: _RegionEnd](var body: _Erased, worker: _WorkerContext):
    body^.take[_ThreadRegion[P, D]]().run()


def _start_on_thread[P: Machine, D: _RegionEnd](pool: BlockingPool, var program: P, token: CancellationToken, config: IORuntimeConfig, var context: ExecutionContext, var runtime: Optional[Runtime], var end: D):
    """Queue a region on `pool`: a current-thread root driven on one of its threads (`_drive_here`).

    A region queued behind a busy pool waits there; if its token is canceled
    meanwhile, its program ends canceled at its first step.
    """
    var region = _ThreadRegion[P, D](program^, token, config, context^, runtime^, end^)
    pool._submit(_Job(_Erased(region^), _run_thread_region[P, D], _Calls()))
