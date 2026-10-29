"""The public contract preserves construction and execution boundaries."""
from algebra_support.tap_contracts import observed
from fp.algebra import ListFamily
from algebra_support.iterators import Counted
from fp.iteration import iterated
from fp.effects import Reader, State, run
from fp.callables import BorrowCallable, BorrowSignature
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct ReaderAudit(BorrowCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = Reader[Int].Pure[NoneType]
    def invoke(self, value: Int) -> Self.Result:
        self.calls[] += 1
        return Reader[Int].pure(NoneType())

@fieldwise_init
struct Reject(BorrowCallable):
    comptime Payload = Int
    comptime Result = Reader[Int].Pure[NoneType]
    comptime Failure = Int
    def invoke(self, value: Int) raises Int -> Self.Result:
        if value == 2: raise 73
        return Reader[Int].pure(NoneType())

def main() raises:
    for count in [0,3]:
        var pulls = 0
        var calls = ArcPointer(0)
        var pending = observed[ListFamily,Reader[Int]](Counted(Pointer(to=pulls),0,count),ReaderAudit(calls))
        assert_equal(pulls,0)
        assert_equal(calls[],0)
        var environment = 10
        assert_equal(run[Reader[Int]](pending^,environment),List[Int]() if count == 0 else List[Int]([1,2,3]))
        assert_equal(pulls,count+1)
        assert_equal(calls[],count)
    var calls = ArcPointer(0)
    _ = observed[ListFamily,Reader[Int]](range(3),ReaderAudit(calls))
    assert_equal(calls[],0)
    def state_audit(value: Int) {calls} -> State[Int].Pure[NoneType]:
        calls[] += 1
        return State[Int].pure(NoneType())
    var state = observed[ListFamily,State[Int]](range(3),BorrowSignature[Int,State[Int].Pure[NoneType]].capture(state_audit))
    assert_equal(calls[],0)
    var output = run[State[Int]](state^,10)
    assert_equal(output[0],[0,1,2])
    assert_equal(output[1],10)
    assert_equal(calls[],3)
    var pulls = 0
    var failed = observed[ListFamily,Reader[Int]](Counted(Pointer(to=pulls),0,5),Reject())
    assert_equal(pulls,0)
    var environment = 0
    var caught = 0
    try: _ = run[Reader[Int]](failed^,environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,73)
    assert_equal(pulls,2)
