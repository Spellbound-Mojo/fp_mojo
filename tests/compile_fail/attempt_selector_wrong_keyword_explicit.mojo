# error: no matching function in call to 'attempt_kwargs'
from fp.data import attempt, attempt_kwargs
@fieldwise_init
struct Token(Movable):
    var value: Int
def callback(var first: Token, /, var **values: Int) -> Int:
    return first.value + len(values)
def main():
    var value = Token(1)
    _ = attempt_kwargs[mutable=True, F=type_of(callback)](callback, value, extra=2)
