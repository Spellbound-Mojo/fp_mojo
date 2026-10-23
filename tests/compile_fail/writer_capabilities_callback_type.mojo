# error: constraint
from fp.algebra import StringMonoid
from fp.effects import Writer, censor, tell
from fp.callables import Unary
@fieldwise_init
struct Wrong(Unary, Defaultable):
    comptime Arg = String
    comptime Out = Int
    def call(self, var log: String) -> Int: return log.byte_length()
def main():
    comptime W = Writer[StringMonoid]
    _ = censor[W](Wrong(), tell[W](String("a")))
