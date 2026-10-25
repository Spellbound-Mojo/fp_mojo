# error: no matching function in call to 'attempt'
from fp.data import attempt, attempt_kwargs
@fieldwise_init
struct Token(Movable):
    var value: Int
def callback(var value: Token):
    _ = value.value
def main():
    var value = Token(1)
    _ = attempt[mutable=True, F=type_of(callback)](callback, value)
