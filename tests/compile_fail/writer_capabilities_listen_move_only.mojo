# error: constraint
from fp.algebra import Monoid
from fp.effects import Writer, ReaderT, LiftListen, tell, listen
@fieldwise_init
struct Token(Movable):
    var value: Int
struct Log(Monoid):
    comptime Value = Token
    @staticmethod
    def empty() -> Token: return Token(0)
    @staticmethod
    def combine(var left: Token, var right: Token) -> Token: return Token(left.value + right.value)
def main():
    comptime W = Writer[Log]
    comptime C = LiftListen[ReaderT[W, Int], W]
    _ = listen[C](tell[C](Token(1)))
