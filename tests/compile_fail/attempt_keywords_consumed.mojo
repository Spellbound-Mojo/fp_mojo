# error: use of uninitialized value
from fp.data import attempt_kwargs
@fieldwise_init
struct Token(Movable):
    var value: Int

def target(var **values: Token) -> Int:
    return len(values)

def main():
    var token = Token(7)
    _ = attempt_kwargs(target, value=token^)
    _ = token.value
