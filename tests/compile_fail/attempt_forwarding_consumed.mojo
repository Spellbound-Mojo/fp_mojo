# error: use of uninitialized value 'value'
from fp.data import attempt
@fieldwise_init
struct Token(Movable):
    var value: Int

def take(var value: Token) -> Token: return value^
def main():
    var value = Token(7)
    _ = attempt(take, value^)
    _ = value.value
