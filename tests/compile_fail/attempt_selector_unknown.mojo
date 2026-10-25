# error: no matching function in call to 'attempt'
from fp.data import attempt
@fieldwise_init
struct Token(Movable):
    var value: Int
def take(var value: Token) -> Int: return value.value
def main():
    var value = Token(7)
    _ = attempt[typo=True](take, value^)
