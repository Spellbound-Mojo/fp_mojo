# error: constraint
from fp.functions import pipeline
from fp.algebra import Monoid
from fp.effects import Writer, writer
@fieldwise_init
struct Token(Movable):
    var value: Int
struct Log(Monoid):
    comptime Value = Token
    @staticmethod
    def empty() -> Token: return Token(0)
    @staticmethod
    def combine(var left: Token, var right: Token) -> Token: return Token(left.value + right.value)
def main(): _ = pipeline(writer[Writer[Log],Int]((Token(1),3))).listen()
