# error: constraint
from fp.effects import Reader, StateT, LiftLocal, action, local, run
from fp.callables import BorrowCallable
@fieldwise_init
struct Read(BorrowCallable, Defaultable):
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = String
    def invoke(self, ref env: Int) raises String capturing -> Int: raise String("source")
def reject(value: Int) raises Int -> Int: raise value

def main() raises:
    comptime R = Reader[Int]
    comptime S = StateT[R, Int]
    var base = run[S](local[LiftLocal[S, R]](S.lift(action[R, Int](Read())), reject), 0)
    try: _ = run[R](base^, 1)
    except: pass
