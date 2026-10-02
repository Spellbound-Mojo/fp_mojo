# error: no matching function in call to 'attempt'
# Native mutable_readonly.mojo pins the detailed mutability diagnostic;
# the public overload set summarizes this rejected read-only argument.
from fp.data import attempt
@fieldwise_init
struct Token(Movable):
    var value: Int

def target(mut value: Token) -> Int:
    value.value += 1
    return value.value

def owner(value: Token):
    _ = attempt(target, value)

def main():
    owner(Token(3))
