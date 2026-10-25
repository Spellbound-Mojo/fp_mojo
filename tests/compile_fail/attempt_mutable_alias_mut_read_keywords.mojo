# error: aliasing values passed mutably
from fp.data import attempt_kwargs
@fieldwise_init
struct Token(Movable):
    var value: Int

def target(mut first: Token, second: Token, /, var **values: Int) -> Int:
    first.value += second.value
    return first.value

def main():
    var value = Token(3)
    _ = attempt_kwargs[mut_read=True](target, value, value, one=7)
