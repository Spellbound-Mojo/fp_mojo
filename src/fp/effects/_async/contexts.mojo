"""Execution contexts: `IO.eval_on`'s regions, seen from the caller.

After Cats Effect's `Async.evalOn`, with a separate root for each region:
`io.eval_on(target)` runs `io` as its own root on the target and
resumes the caller on its own root with the outcome. A fiber never migrates
between schedulers.

The caller's side is an `IO.async` registration that shares `interruptible`'s
machinery (`blocking.mojo`):

- The registration (`_SubmitRegion`) starts the region's root under a fresh
  token held in an `_Interrupt`: on a work-stealing `Runtime` a detached root
  (`Runtime._start_region`, `_DetachedRoot`); on a current-thread `Runtime` or
  a `BlockingPool`, a current-thread root driven on one blocking thread
  (`_start_on_thread`).
- When the root has finished and released everything, `_RegionDone` completes
  the registration's `Completion` and reports the return.
- The withdrawal is `_AwaitReturn`: it cancels the region's token and waits
  for that report. The registration is unmasked, as `interruptible`'s is, so
  canceling the caller reaches `io`'s own checkpoints; the withdrawal runs
  masked after every entered registration, so the caller always waits for the
  region's end, and `io`'s finalizers run on the target exactly once.

The caller's continuation resumes through `Completion`'s foreign wake, which
works from every kind of root: a pool's, the current thread's, `Driver` and
`TestControl`.

`execution_context` reads the root's context word (`_Scheduler.context_box`),
which the root's owner installs before the root runs: `Runtime.run` and
regions install their target; the free `run`, `Driver` and `TestControl`
install nothing.
"""
from std.builtin.rebind import rebind_var
from std.os import abort
from fp.callables.protocols import OnceUnary
from fp.data import Result, Ok
from fp.effects import IOContext, EffectFailure, Outcome
from .blocking import _Interrupt
from .callbacks import Completion
from .kernel import IORuntimeConfig, Machine, Step
from .runtime import ExecutionContext, _RegionEnd, _start_on_thread


struct _RegionDone[T: Movable & Deinitable, E: Movable & Deinitable](_RegionEnd):
    """Resume the caller with the region's outcome, then release its withdrawal."""
    comptime Value = Self.T
    comptime Error = Self.E
    var completion: Completion[Self.T, Self.E]
    var interrupt: _Interrupt[Self.E]

    def __init__(out self, var completion: Completion[Self.T, Self.E], var interrupt: _Interrupt[Self.E]):
        self.completion = completion^
        self.interrupt = interrupt^

    def finish(deinit self, var outcome: Outcome[Self.T, Self.E]):
        # A withdrawal that began first rejects the outcome, which is then
        # destroyed here, on the target's thread.
        _ = self.completion.complete(outcome^)
        self.interrupt.returned()


struct _SubmitRegion[P: Machine](OnceUnary):
    """The registration of `eval_on`: start the region's root on its target."""
    var program: Self.P
    var target: ExecutionContext
    var settings: IORuntimeConfig
    var interrupt: _Interrupt[Self.P.Error]
    comptime Arg = Completion[Self.P.Value, Self.P.Error]
    comptime Out = NoneType

    def __init__(out self, var program: Self.P, var target: ExecutionContext, var settings: IORuntimeConfig, var interrupt: _Interrupt[Self.P.Error]):
        self.program = program^
        self.target = target^
        self.settings = settings^
        self.interrupt = interrupt^

    def call_once(deinit self, var completion: Self.Arg) -> NoneType:
        var token = self.interrupt.token.copy()
        var end = _RegionDone[Self.P.Value, Self.P.Error](completion^, self.interrupt^)
        if self.target._runtime:
            self.target._runtime.value()._start_region(self.program^, token, end^)
        else:
            var pool = self.target._pool.value().copy()
            _start_on_thread(pool, self.program^, token, self.settings, self.target^, None, end^)
        return None


struct _CurrentSettings[E: Movable & Deinitable](Machine, Defaultable):
    """The running root's interpreter settings, for a region on a `BlockingPool`.

    A region on a runtime uses that runtime's configuration instead. A
    blocking pool has none, so the region keeps its caller's thresholds and
    reporting, with no configured blocking pool of its own: its blocking calls
    then use a private pool, and never wait behind the region on its target.
    """
    comptime Value = IORuntimeConfig
    comptime Error = Self.E

    def __init__(out self):
        pass

    def poll(mut self, context: IOContext[Self.E]) -> Step[IORuntimeConfig, Self.E]:
        var settings = IORuntimeConfig()
        if context._budget:
            ref budget = context._budget.value()[]
            settings.auto_yield_threshold = budget.yield_threshold
            settings.cancelation_check_threshold = budget.check_threshold
            settings.report_unhandled_fiber_errors = budget.report
            settings.reporter = budget.reporter
        return Step[IORuntimeConfig, Self.E].ready(Optional(Result[IORuntimeConfig, EffectFailure[Self.E]](Ok(settings^))))


struct _CurrentContext[E: Movable & Deinitable](Machine, Defaultable):
    """Read the running root's execution context once (`IO.execution_context`)."""
    comptime Value = Optional[ExecutionContext]
    comptime Error = Self.E

    def __init__(out self):
        pass

    def poll(mut self, context: IOContext[Self.E]) -> Step[Optional[ExecutionContext], Self.E]:
        var found = Optional[ExecutionContext]()
        if context._runtime:
            var box = context._runtime.value().scheduler()[].context_box()
            if box:
                found = Optional(box.value()[].pointer[ExecutionContext]()[].copy())
        return Step[Optional[ExecutionContext], Self.E].ready(Optional(Result[Optional[ExecutionContext], EffectFailure[Self.E]](Ok(found^))))
