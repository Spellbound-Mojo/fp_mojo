# error: no matching function in call to 'merge'
from fp.functions import merge
from fp.callables import Unary
@fieldwise_init
struct Token(Movable):
    var id: Int
struct Keep(Unary):
    comptime Arg = Token
    comptime Out = Token
    def __init__(out self): pass
    def call(self, var value: Token) -> Token: return value^
def main(): _ = merge(Keep(), Keep())
