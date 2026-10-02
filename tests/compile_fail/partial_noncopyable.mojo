# error: no matching function in call to 'partial'
# error: argument type 'Token' does not conform
# Every call receives a fresh copy of each bound value.
from fp.functions import partial
@fieldwise_init
struct Token(Movable):
    var value: Int
def read(token: Token, x: Int) -> Int:
    return token.value + x
def main():
    var token = Token(1)
    _ = partial(read, token)
