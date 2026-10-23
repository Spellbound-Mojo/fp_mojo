# error: constraint
from fp.algebra import StringMonoid
from fp.effects import Writer, ReaderT, LiftCensor, action, censor
from fp.callables import BorrowCallable
@fieldwise_init
struct Source(BorrowCallable, Defaultable):
    comptime Payload = Int
    comptime Result = Writer[StringMonoid].Told
    comptime Failure = String
    def invoke(self, ref env: Int) raises String capturing -> Self.Result: raise String("source")
def reject(var log: String) raises Int -> String: raise 7
def main():
    comptime W = Writer[StringMonoid]
    comptime R = ReaderT[W, Int]
    _ = censor[LiftCensor[R, W]](reject, action[R, NoneType](Source()))
