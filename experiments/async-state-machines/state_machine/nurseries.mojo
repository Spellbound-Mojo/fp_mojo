"""Bounded runtime admission with one typed owner for every accepted child."""
from std.atomic import Atomic
from std.collections import Deque
from std.memory import ArcPointer
from std.os import abort
from std.time import monotonic
from fp.data import Result, Ok
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure
from fp.effects.coordination import _Cell, _lock, _try_lock, _try_pop
from fp.effects.outcomes import _finish
from .kernel import Machine, Step, Wait, Signal, _tick
from .children import _Child, _Drain


@fieldwise_init
struct _Admission[P: Machine](Movable):
    var closed: Bool
    var accepted: Int
    var limit: Int
    var queue: Deque[Self.P]

    def pending(deinit self) -> Deque[Self.P]:
        return self.queue^


@fieldwise_init
struct _Incoming[P: Machine](Movable):
    var closed: Bool
    var more: Bool
    var program: Optional[Self.P]


@fieldwise_init
struct Spawner[P: Machine](Copyable):
    """Submission capability; accepted work remains owned by its nursery."""
    var _cell: ArcPointer[_Cell[_Admission[Self.P]]]
    var _signal: Signal
    var _mask: IOContext[Self.P.Error]

    def try_spawn(self, var program: Self.P) -> Optional[Self.P]:
        var pending = Optional(program^)
        var locked = _lock(self._cell, self._mask)
        var guard = locked.take()
        var accepted = not guard.cell[].slot.value().closed and guard.cell[].slot.value().accepted < guard.cell[].slot.value().limit
        if accepted:
            guard.cell[].slot.value().accepted += 1
            guard.cell[].slot.value().queue.append(pending.take())
        _ = guard^
        self._signal.notify()
        return pending^

    def close(self):
        var locked = _lock(self._cell, self._mask)
        var guard = locked.take()
        var changed = not guard.cell[].slot.value().closed
        guard.cell[].slot.value().closed = True
        _ = guard^
        if changed:
            self._signal.notify()

    def _next(self) -> Optional[_Incoming[Self.P]]:
        var locked = _try_lock(self._cell)
        if not locked:
            return None
        var guard = locked.take()
        var program = _try_pop(guard.cell[].slot.value().queue)
        var incoming = _Incoming(guard.cell[].slot.value().closed,
                                 len(guard.cell[].slot.value().queue) != 0, program^)
        _ = guard^
        return Optional(incoming^)

    def _withdraw(self) -> Deque[Self.P]:
        var locked = _lock(self._cell, self._mask)
        var guard = locked.take()
        var old = guard.cell[].slot.take()
        guard.cell[].slot = Optional(_Admission[Self.P](True, old.accepted, old.limit, Deque[Self.P]()))
        _ = guard^
        self._signal.notify()
        # Dropping unopened recipes can invoke arbitrary user destructors.
        return old^.pending()


struct Nursery[P: Machine](Machine):
    comptime Value = List[Self.P.Value]
    comptime Error = Self.P.Error
    var _admission: Spawner[Self.P]
    var _children: List[_Child[Self.P, Self.P.Value, Self.P.Error]]
    var _drain: _Drain
    var _turn: Int
    var _phase: Int
    var _collected: Int
    var _result: Optional[Outcome[Self.Value, Self.Error]]

    def __init__(out self, limit: Int):
        if limit < 0:
            abort("nursery admission limit must be nonnegative")
        self._admission = Spawner(
            ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_Admission[Self.P](False, 0, limit, Deque[Self.P]())))),
            Signal(), IOContext[Self.Error](CancellationToken(), True))
        self._children = List[_Child[Self.P, Self.P.Value, Self.P.Error]]()
        self._drain = _Drain()
        self._turn = 0
        self._phase = 0
        self._collected = 0
        self._result = Optional(Outcome[Self.Value, Self.Error](Result[Self.Value, EffectFailure[Self.Error]](Ok(Self.Value()))))

    def __deinit__(deinit self):
        _ = self._admission._withdraw()

    def spawner(self) -> Spawner[Self.P]:
        return self._admission.copy()

    def _stop(mut self, context: IOContext[Self.Error], failed: Bool):
        if self._drain.observe(context, failed):
            self._admission.close()
            # This compiler's List iterator requires Copyable elements.
            for index in range(len(self._children)):
                self._children[index].cancel()

    def _collect(mut self) -> Step[Self.Value, Self.Error]:
        if self._collected == len(self._children):
            self._phase = 2
            return .ready(self._result.take())
        var outcome = self._children[self._collected].slot.take_outcome()
        var result = self._result.take()
        if result and outcome and result.value().is_ok() and outcome.value().is_ok():
            var values = result.take()._take_ok()
            values.append(outcome.take()._take_ok())
            result = Optional(Result[Self.Value, EffectFailure[Self.Error]](Ok(values^)))
        else:
            result = _finish(result^, outcome^)
        self._result = Optional(result^)
        self._collected += 1
        return .pending(Wait())

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        if self._phase == 1:
            return self._collect()
        if self._phase == 2:
            abort("nursery polled after completion")
        var revision = self._admission._signal.revision()
        self._stop(context, False)
        var received = self._admission._next()
        var closed = False
        var more = False
        if received:
            var incoming = received.take()
            closed = incoming.closed
            more = incoming.more
            if incoming.program:
                var child = _Child[Self.P, Self.P.Value, Self.P.Error](incoming.program.take())
                if self._drain.requested:
                    child.cancel()
                self._children.append(child^)
        var count = len(self._children)
        var now = monotonic()
        for offset in range(count):
            var index = (self._turn + offset) % count
            if self._children[index].ready(now):
                self._turn = (index + 1) % count
                _ = _tick(self._children[index].slot, self._children[index].context)
                self._stop(context, self._children[index].slot.failed())
                break
        var complete = closed and not more
        var wait = self._drain.waiting()
        wait.signal = Optional(self._admission._signal.copy())
        wait.revision = revision
        wait.runnable = more
        for index in range(count):
            complete = complete and self._children[index].slot.done()
            self._children[index].include(wait)
        if complete:
            self._phase = 1
            return .pending(Wait())
        return .pending(wait^)
