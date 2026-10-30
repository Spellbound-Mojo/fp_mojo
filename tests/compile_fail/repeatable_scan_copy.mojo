# error: no matching function in call to 'scan_left'
from fp.callables import MutableBinary
from fp.iteration import scan_left
@fieldwise_init
struct Token(Movable):
    var value: Int
struct Keep(MutableBinary):
    comptime First = Token
    comptime Second = Int
    comptime Out = Token
    def __init__(out self): pass
    def call_mut(mut self, var carry: Token, var value: Int) -> Token: return carry^
def main(): _ = scan_left(range(2), Token(0), Keep())
