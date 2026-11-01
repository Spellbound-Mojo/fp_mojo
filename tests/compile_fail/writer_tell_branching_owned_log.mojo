# error: constraint
from fp.effects import WriterT, writer
from fp.algebra import Monoid, ListFamily
from fp.functions import pipeline
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
    comptime W = WriterT[ListFamily,Log]
    var values = List[Tuple[Token,Int]]()
    values.append((Token(1),7))
    var value = writer[W,Int](values^)
    _ = pipeline(value^).tell(Token(2))
