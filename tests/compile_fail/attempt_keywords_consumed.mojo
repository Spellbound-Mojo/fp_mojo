# error: use of uninitialized value
from fp.data import attempt
@fieldwise_init
struct Token(Movable):
    var value: Int

def target(var **values: Token) -> Int:
    return len(values)

def main():
    var token = Token(7)
    _ = attempt(target, value=token^)
    _ = token.value
