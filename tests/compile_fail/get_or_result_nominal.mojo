# error: cannot be converted
from fp.data import err
@fieldwise_init
struct Token(Movable):
    var value: Int
@fieldwise_init
struct Other(Movable):
    var value: Int
def main():
    _ = err[Token]("bad").get_or(Other(7))
