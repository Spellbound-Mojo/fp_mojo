# error: no matching function in call to 'attempt'
from fp.data import attempt, attempt_kwargs
@fieldwise_init
struct Token(Movable):
    var value: Int
def callback(mut first: Token, var second: Token) -> Int:
    first.value += second.value
    return first.value
def main():
    var first = Token(1)
    var second = Token(2)
    _ = attempt[owned_mut=True, F=type_of(callback)](callback, first^, second)
