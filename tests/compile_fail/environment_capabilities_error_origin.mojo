# error: cannot call function that may raise
from fp.effects import Reader, StateT, LiftLocal, ask, local, run
from fp.callables import BorrowOnceCallable
@fieldwise_init
struct Reject[o: ImmOrigin](BorrowOnceCallable):
    var view: Span[Int, Self.o]
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = Span[Int, Self.o]
    def invoke_once(deinit self, ref value: Int) raises Self.Failure capturing -> Int: raise self.view

def bad(left: List[Int], right: List[Int]) raises Span[Int, origin_of(left)]:
    comptime R = Reader[Int]
    comptime S = StateT[R, Int]
    comptime C = LiftLocal[S, R]
    var base = run[S](local[C](Reject[origin_of(right)](Span(right)), ask[C]()), 0)
    _ = run[R](base^, 1)
def main() raises:
    try: bad([1], [2])
    except: pass
