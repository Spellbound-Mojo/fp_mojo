# error: does not conform to trait 'Copyable'
from std.iter import map

@fieldwise_init
struct Token(Movable):
    var value: Int

def token(var value: Int) -> Token:
    return Token(value)

def main():
    _ = map[token](range(3))
