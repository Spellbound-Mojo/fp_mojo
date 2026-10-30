# error: use of uninitialized value
from fp.algebra import StringMonoid
from fp.effects import Writer, ReaderT, LiftCensor, tell, censor
from fp.callables import OnceUnary
@fieldwise_init
struct Change(OnceUnary):
    var text: String
    comptime Arg = String
    comptime Out = String
    def call_once(deinit self, var log: String) -> String: return log + self.text
def main():
    comptime W = Writer[StringMonoid]
    comptime C = LiftCensor[ReaderT[W, Int], W]
    var callback = Change(String("!"))
    _ = censor[C](tell[C](String("a")), callback^)
    _ = censor[C](tell[C](String("b")), callback^)
