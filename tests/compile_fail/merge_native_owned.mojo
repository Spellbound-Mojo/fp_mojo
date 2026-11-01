# error: no matching function in call to 'merge'
from fp.functions import merge
@fieldwise_init
struct Token(Movable):
    var id: Int
def keep(var value: Token) -> Token: return value^
def main(): _ = merge(keep, keep)
