"""Generic fiber forwarding and independently borrowed results retain origins."""
from fp.effects import IOContract, ReaderAction, delay, run_io
from fp.callables import OnceThunk, BorrowCallable
from fp.effects import Fiber, unsafe_start
from fp.effects import Ref, Queue
from std.testing import assert_equal
from std.sys.info import CompilationTarget


def start_forward[P: ReaderAction](var program: P) raises -> Fiber[P] where IOContract[P].Compatible:
    return unsafe_start(program^)


def join_forward[P: ReaderAction](var child: Fiber[P]) -> IOContract[P].Out:
    return child^.join()


@fieldwise_init
struct FiberIndependent[o: ImmOrigin](OnceThunk):
    var owner: Pointer[List[Int], Self.o]
    comptime Out = Span[Int, Self.o]
    def call_once(deinit self) -> Self.Out:
        return Span(self.owner[])


@fieldwise_init
struct RefIndependent[o: ImmOrigin](BorrowCallable):
    var owner: Pointer[List[Int], Self.o]
    comptime Payload = Int
    comptime Result = Span[Int, Self.o]
    def invoke(self, ref value: Int) -> Self.Result:
        return Span(self.owner[])


def queue_borrow[o: ImmOrigin](ref[o] owner: List[Int]) raises:
    var queue = Queue[Span[Int, o]](1)
    _ = run_io(queue.offer[Error](Span(owner)))
    var taken = run_io(queue.take[Error]())
    var taken_result = taken.take()
    var queued_view = taken_result^._take_ok()
    assert_equal(queued_view[0], 7)


def main() raises:
    var owner = List[Int]([7, 8])
    var state = Ref(1)
    var inspected = run_io(state.inspect[Error](RefIndependent(Pointer(to=owner))))
    var inspected_result = inspected.take()
    var view = inspected_result^._take_ok()
    assert_equal(view[1], 8)
    queue_borrow(owner)
    comptime if CompilationTarget.is_linux():
        # The worker only reads this owner and joins before the owner dies.
        var child = start_forward(delay[Error](FiberIndependent(Pointer(to=owner))))
        var outcome = join_forward(child^)
        var result = outcome.take()
        var fiber_view = result^._take_ok()
        assert_equal(fiber_view[1], 8)
