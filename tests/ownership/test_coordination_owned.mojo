"""Move-only shared state, queue transfers, and cancellation release owners once."""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from std.sys.info import CompilationTarget
from fp.effects import Ref, Deferred, Queue
from fp.effects import unsafe_start
from fp.effects import CancellationToken, IOContract, ReaderAction, run_io, delay
from fp.callables import OnceUnary, OnceThunk


struct CoordOwner(Movable):
    var id: Int
    var drops: ArcPointer[Atomic[Int]]
    def __init__(out self, id: Int, var drops: ArcPointer[Atomic[Int]]):
        self.id = id
        self.drops = drops^
    def __deinit__(deinit self):
        _ = self.drops[].fetch_add(1)



struct CoordCopyOwner(Copyable):
    var id: Int
    var created: ArcPointer[Atomic[Int]]
    var destroyed: ArcPointer[Atomic[Int]]
    def __init__(out self, id: Int, var created: ArcPointer[Atomic[Int]], var destroyed: ArcPointer[Atomic[Int]]):
        self.id = id
        self.created = created^
        self.destroyed = destroyed^
        _ = self.created[].fetch_add(1)
    def __init__(out self, *, copy: Self):
        self.id = copy.id
        self.created = copy.created.copy()
        self.destroyed = copy.destroyed.copy()
        _ = self.created[].fetch_add(1)
    def __deinit__(deinit self):
        _ = self.destroyed[].fetch_add(1)


def owned_coord_value[P: ReaderAction](var program: P) raises -> P.Value where IOContract[P].Compatible:
    var outcome = run_io(program^)
    assert_true(Bool(outcome))
    var result = outcome.take()
    assert_true(result.is_ok())
    return result^._take_ok()


def owned_coord_id(value: CoordOwner) -> Int:
    return value.id


def owned_coord_inc(var value: Int) -> Int:
    return value + 1


@fieldwise_init
struct CoordReenter(Movable):
    var cell: Ref[Int]
    def __deinit__(deinit self):
        _ = run_io(self.cell.update[Never](owned_coord_inc))


@fieldwise_init
struct CoordCancelResult(OnceUnary):
    var cell: Ref[Int]
    var token: CancellationToken
    comptime Arg = Int
    comptime Out = Tuple[Int, CoordReenter]
    def call_once(deinit self, var value: Int) -> Self.Out:
        self.token.cancel()
        return (value, CoordReenter(self.cell^))


@fieldwise_init
struct CoordReturnOwner(OnceThunk):
    var owner: CoordOwner
    comptime Out = CoordOwner
    def call_once(deinit self) -> Self.Out:
        return self.owner^


@fieldwise_init
struct CoordRaiseOwner(OnceThunk):
    var owner: CoordOwner
    comptime Out = Int
    comptime Error = CoordOwner
    def call_once(deinit self) raises Self.Error -> Int:
        raise self.owner^


def main() raises:
    var drops = ArcPointer(Atomic(Int(0)))
    var state = Ref(CoordOwner(1, drops.copy()))
    var previous = owned_coord_value(state.get_and_set[Error](CoordOwner(2, drops.copy())))
    assert_equal(previous.id, 1)
    assert_equal(owned_coord_value(state.inspect[Error](owned_coord_id)), 2)
    _ = previous^
    assert_equal(drops[].load(), 1)
    _ = owned_coord_value(state.set[Error](CoordOwner(3, drops.copy())))
    assert_equal(drops[].load(), 2)
    _ = state^
    assert_equal(drops[].load(), 3)

    var cell = Ref(0)
    var token = CancellationToken()
    var pending = cell.modify[Error, CoordReenter](CoordCancelResult(cell.copy(), token.copy()))
    assert_true(not run_io(pending^, token))
    # The canceled returned owner reenters this same cell while being destroyed.
    # Settling before unlocking would deadlock here.
    assert_equal(owned_coord_value(cell.get[Error]()), 1)

    var created = ArcPointer(Atomic(Int(0)))
    var destroyed = ArcPointer(Atomic(Int(0)))
    var deferred = Deferred[CoordCopyOwner]()
    var unused = deferred.complete[Error](CoordCopyOwner(1, created.copy(), destroyed.copy()))
    _ = unused^
    assert_equal(destroyed[].load(), 1)
    assert_true(owned_coord_value(deferred.complete[Error](CoordCopyOwner(2, created.copy(), destroyed.copy()))))
    assert_true(not owned_coord_value(deferred.complete[Error](CoordCopyOwner(3, created.copy(), destroyed.copy()))))
    assert_equal(destroyed[].load(), 2)
    var copy_a = owned_coord_value(deferred.get[Error]())
    var copy_b = owned_coord_value(deferred.get[Error]())
    assert_equal(copy_a.id, 2)
    assert_equal(copy_b.id, 2)
    assert_equal(created[].load(), 5)
    _ = copy_a^
    _ = copy_b^
    _ = deferred^
    assert_equal(destroyed[].load(), created[].load())

    var queue = Queue[CoordOwner](1)
    _ = owned_coord_value(queue.offer[Error](CoordOwner(4, drops.copy())))
    var rejected = owned_coord_value(queue.try_offer[Error](CoordOwner(5, drops.copy())))
    var rejected_owner = rejected.take()
    assert_equal(rejected_owner.id, 5)
    _ = rejected_owner^
    assert_equal(drops[].load(), 4)
    var removed = owned_coord_value(queue.take[Error]())
    assert_equal(removed.id, 4)
    _ = removed^
    assert_equal(drops[].load(), 5)
    var unopened = queue.offer[Error](CoordOwner(6, drops.copy()))
    _ = unopened^
    assert_equal(drops[].load(), 6)
    _ = owned_coord_value(queue.offer[Error](CoordOwner(7, drops.copy())))
    comptime if CompilationTarget.is_linux():
        var blocked = unsafe_start(queue.offer[Error](CoordOwner(8, drops.copy())))
        assert_true(not blocked^.cancel())
        assert_equal(drops[].load(), 7)
        var child = unsafe_start(delay[Error](CoordReturnOwner(CoordOwner(9, drops.copy()))))
        var returned = child^.join()
        var returned_result = returned.take()
        var returned_owner = returned_result^._take_ok()
        assert_equal(returned_owner.id, 9)
        _ = returned_owner^
        assert_equal(drops[].load(), 8)
        var failed = unsafe_start(delay[CoordOwner](CoordRaiseOwner(CoordOwner(10, drops.copy()))))
        var failure = failed^.join()
        var failure_result = failure.take()
        var owned_errors = failure_result^._take_err()
        var errors = owned_errors^.into_errors()
        assert_equal(errors.first().id, 10)
        _ = errors^
        assert_equal(drops[].load(), 9)
        _ = queue^
        assert_equal(drops[].load(), 10)
    else:
        _ = queue^
        assert_equal(drops[].load(), 7)
