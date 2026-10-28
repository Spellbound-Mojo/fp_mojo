"""Coordination linearizes updates, completion and ownership under contention."""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from std.time import sleep, monotonic
from std.sys.info import CompilationTarget
from fp.effects import Ref, Deferred, Semaphore, Queue
from fp.effects import unsafe_start
from fp.effects import IO, IOContext, IOContract, Outcome, ReaderAction, run_io, delay, canceled, guarantee
from fp.effects.io import _run_io
from fp.callables import OnceThunk


def coord_value[P: ReaderAction](var program: P) raises -> P.Value where IOContract[P].Compatible:
    var outcome = run_io(program^)
    assert_true(Bool(outcome))
    var result = outcome.take()
    assert_true(result.is_ok())
    return result^._take_ok()


def coord_increment(var value: Int) -> Int:
    return value + 1


def coord_swap(var value: Int) -> Tuple[Int, Int]:
    return (value + 1, value)


def coord_fail(value: Int) raises Int -> Int:
    raise value


def coord_answer() -> Int:
    return 42


def coord_wait(count: ArcPointer[Atomic[Int]], target: Int) raises:
    var deadline = monotonic() + 10_000_000_000
    while count[].load() < target:
        if monotonic() > deadline:
            raise Error("coordination worker did not reach its checkpoint")
        sleep(0.001)


@fieldwise_init
struct CoordIncrementMany(ReaderAction):
    var state: Ref[Int]
    var ready: ArcPointer[Atomic[Int]]
    var gate: ArcPointer[Atomic[UInt8]]
    comptime Family = IO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]
    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        _ = self.ready[].fetch_add(1)
        while self.gate[].load() == 0:
            if context.canceled():
                return None
            sleep(0.001)
        for _ in range(1000):
            var updated = _run_io(self.state.update[Error](coord_increment), context)
            if not updated:
                return None
        return _run_io(self.state.update[Error](coord_increment), context)


@fieldwise_init
struct CoordComplete(ReaderAction):
    var target: Deferred[Int]
    var value: Int
    var ready: ArcPointer[Atomic[Int]]
    var gate: ArcPointer[Atomic[UInt8]]
    comptime Family = IO[Error]
    comptime Env = IOContext[Error]
    comptime Value = Bool
    comptime Out[o: ImmOrigin] = Outcome[Bool, Error]
    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        _ = self.ready[].fetch_add(1)
        while self.gate[].load() == 0:
            if context.canceled():
                return None
            sleep(0.001)
        return _run_io(self.target.complete[Error](self.value), context)


@fieldwise_init
struct CoordAnnounce[P: ReaderAction](ReaderAction):
    var program: Self.P
    var ready: ArcPointer[Atomic[Int]]
    comptime Family = Self.P.Family
    comptime Env = Self.P.Env
    comptime Value = Self.P.Value
    comptime Out[o: ImmOrigin] = Self.P.Out[o]
    comptime Error[o: ImmOrigin] = Self.P.Error[o]
    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        comptime assert IOContract[Self.P].Compatible
        _ = self.ready[].fetch_add(1)
        return self.program^.run(context)



@fieldwise_init
struct CoordCritical(ReaderAction, Copyable):
    var active: ArcPointer[Atomic[Int]]
    var violations: ArcPointer[Atomic[Int]]
    var ready: ArcPointer[Atomic[Int]]
    var gate: ArcPointer[Atomic[UInt8]]
    comptime Family = IO[Error]
    comptime Env = IOContext[Error]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Outcome[Int, Error]
    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        var previous = self.active[].fetch_add(1)
        if previous >= 2:
            _ = self.violations[].fetch_add(1)
        _ = self.ready[].fetch_add(1)
        while self.gate[].load() == 0 and not context.canceled():
            sleep(0.001)
        _ = self.active[].fetch_sub(1)
        return _run_io(delay[Error](coord_answer), context)


def coord_serial() raises:
    var state = Ref(1)
    var pending = state.update[Error](coord_increment)
    assert_equal(coord_value(state.get[Error]()), 1)
    _ = coord_value(pending^)
    assert_equal(coord_value(state.modify[Error, Int](coord_swap)), 2)
    assert_equal(coord_value(state.get_and_set[Error](9)), 3)
    var failed = run_io(state.inspect[Int](coord_fail))
    var failed_result = failed.take()
    var failure = failed_result^._take_err()
    var errors = failure^.into_errors()
    assert_equal(errors.first(), 9)
    _ = coord_value(state.set[Error](4))
    assert_equal(coord_value(state.get[Error]()), 4)

    var deferred = Deferred[Int]()
    assert_true(not coord_value(deferred.try_get[Error]()))
    assert_true(coord_value(deferred.complete[Error](17)))
    assert_true(not coord_value(deferred.complete[Error](19)))
    assert_equal(coord_value(deferred.get[Error]()), 17)

    var sem = Semaphore(1)
    var permit = coord_value(sem.acquire[Error]())
    assert_equal(coord_value(sem.available[Error]()), 0)
    _ = permit^
    assert_equal(coord_value(sem.available[Error]()), 1)
    assert_equal(coord_value(sem.with_permit(delay[Error](coord_answer))), 42)
    assert_true(not run_io(sem.with_permit(canceled[Error]())))
    assert_equal(coord_value(sem.available[Error]()), 1)

    var queue = Queue[Int](2)
    assert_true(not coord_value(queue.try_offer[Error](1)))
    _ = coord_value(queue.offer[Error](2))
    var rejected = coord_value(queue.try_offer[Error](3))
    assert_equal(rejected.take(), 3)
    assert_equal(coord_value(queue.size[Error]()), 2)
    assert_equal(coord_value(queue.take[Error]()), 1)
    assert_equal(coord_value(queue.take[Error]()), 2)
    assert_true(not coord_value(queue.try_take[Error]()))
    var invalid = 0
    try:
        _ = Semaphore(-1)
    except:
        invalid += 1
    try:
        _ = Queue[Int](0)
    except:
        invalid += 1
    assert_equal(invalid, 2)


def coord_parallel() raises:
    var ready = ArcPointer(Atomic(Int(0)))
    var gate = ArcPointer(Atomic(UInt8(0)))
    var state = Ref(0)
    var first = unsafe_start(CoordIncrementMany(state.copy(), ready.copy(), gate.copy()))
    var second = unsafe_start(CoordIncrementMany(state.copy(), ready.copy(), gate.copy()))
    var third = unsafe_start(CoordIncrementMany(state.copy(), ready.copy(), gate.copy()))
    coord_wait(ready, 3)
    gate[].store(1)
    _ = first^.join()
    _ = second^.join()
    _ = third^.join()
    assert_equal(coord_value(state.get[Error]()), 3003)

    ready[].store(0)
    gate[].store(0)
    var deferred = Deferred[Int]()
    var a = unsafe_start(CoordComplete(deferred.copy(), 11, ready.copy(), gate.copy()))
    var b = unsafe_start(CoordComplete(deferred.copy(), 22, ready.copy(), gate.copy()))
    var read_a = unsafe_start(deferred.get[Error]())
    var read_b = unsafe_start(deferred.get[Error]())
    coord_wait(ready, 2)
    gate[].store(1)
    var a_out = a^.join()
    var b_out = b^.join()
    var a_result = a_out.take()
    var b_result = b_out.take()
    assert_equal(Int(a_result^._take_ok()) + Int(b_result^._take_ok()), 1)
    var read_a_out = read_a^.join()
    var read_b_out = read_b^.join()
    var read_a_result = read_a_out.take()
    var read_b_result = read_b_out.take()
    assert_equal(read_a_result^._take_ok(), read_b_result^._take_ok())
    var empty = Deferred[Int]()
    var canceled_read = unsafe_start(empty.get[Error]())
    assert_true(not canceled_read^.cancel())

    var sem = Semaphore(1)
    var permit = coord_value(sem.acquire[Error]())
    ready[].store(0)
    var blocked = unsafe_start(CoordAnnounce(sem.acquire[Error](), ready.copy()))
    coord_wait(ready, 1)
    assert_true(not blocked.done())
    assert_true(not blocked^.cancel())
    assert_equal(coord_value(sem.available[Error]()), 0)
    _ = permit^
    assert_equal(coord_value(sem.available[Error]()), 1)

    ready[].store(0)
    gate[].store(0)
    var two = Semaphore(2)
    var active = ArcPointer(Atomic(Int(0)))
    var violations = ArcPointer(Atomic(Int(0)))
    var critical = CoordCritical(active.copy(), violations.copy(), ready.copy(), gate.copy())
    var c1 = unsafe_start(two.with_permit(critical.copy()))
    var c2 = unsafe_start(two.with_permit(critical.copy()))
    var c3 = unsafe_start(two.with_permit(critical.copy()))
    var c4 = unsafe_start(two.with_permit(critical^))
    coord_wait(ready, 2)
    assert_equal(active[].load(), 2)
    gate[].store(1)
    _ = c1^.join()
    _ = c2^.join()
    _ = c3^.join()
    _ = c4^.join()
    assert_equal(active[].load(), 0)
    assert_equal(violations[].load(), 0)
    assert_equal(ready[].load(), 4)
    assert_equal(coord_value(two.available[Error]()), 2)

    var queue = Queue[Int](1)
    _ = coord_value(queue.offer[Error](1))
    ready[].store(0)
    var writer = unsafe_start(CoordAnnounce(queue.offer[Error](2), ready.copy()))
    coord_wait(ready, 1)
    assert_true(not writer.done())
    assert_equal(coord_value(queue.take[Error]()), 1)
    assert_true(Bool(writer^.join()))
    assert_equal(coord_value(queue.take[Error]()), 2)
    ready[].store(0)
    var reader = unsafe_start(CoordAnnounce(queue.take[Error](), ready.copy()))
    coord_wait(ready, 1)
    _ = coord_value(queue.offer[Error](3))
    var read_out = reader^.join()
    var read_result = read_out.take()
    assert_equal(read_result^._take_ok(), 3)
    var blocked_reader = unsafe_start(queue.take[Error]())
    assert_true(not blocked_reader^.cancel())


def main() raises:
    coord_serial()
    comptime if CompilationTarget.is_linux():
        coord_parallel()
