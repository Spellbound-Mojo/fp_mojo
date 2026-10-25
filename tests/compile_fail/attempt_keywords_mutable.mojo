# error: no matching function in call to 'attempt_kwargs'
# Native mutable_readonly.mojo pins the detailed mutability diagnostic;
# the public overload set summarizes this rejected read-only argument.
from fp.data import attempt_kwargs
@fieldwise_init
struct Token(Movable):
    var value: Int

def target(mut value: Token, /, var **values: Int) -> Int:
    value.value += 1
    return value.value

def owner(value: Token):
    _ = attempt_kwargs(target, value, one=7)

def main():
    owner(Token(3))
