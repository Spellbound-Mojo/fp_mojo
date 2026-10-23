# error: constraint
from fp.algebra import StringMonoid
from fp.effects import Writer, ReaderT, LiftCensor, action, censor
from fp.callables import BorrowOnceCallable, OnceUnary
@fieldwise_init
struct Source[o: ImmOrigin](BorrowOnceCallable):
    var view: Span[Int, Self.o]
    comptime Payload = Int
    comptime Result = Writer[StringMonoid].Told
    comptime Failure = Span[Int, Self.o]
    def invoke_once(deinit self, ref env: Int) raises Self.Failure capturing -> Self.Result: raise self.view
@fieldwise_init
struct Reject[o: ImmOrigin](OnceUnary):
    var view: Span[Int, Self.o]
    comptime Arg = String
    comptime Out = String
    comptime Error = Span[Int, Self.o]
    def call_once(deinit self, var log: String) raises Self.Error -> String: raise self.view
def bad(left: List[Int], right: List[Int]):
    comptime W = Writer[StringMonoid]
    comptime R = ReaderT[W, Int]
    _ = censor[LiftCensor[R, W]](Reject[origin_of(right)](Span(right)), action[R, NoneType](Source[origin_of(left)](Span(left))))
def main(): bad([1], [2])
