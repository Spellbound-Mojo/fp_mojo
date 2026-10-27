# error: cannot be converted
from fp.data import err
from fp.functions import pipeline
@fieldwise_init
struct Token(Movable):
    var value: Int
@fieldwise_init
struct Other(Movable):
    var value: Int
def main():
    _ = pipeline(err[Token]("bad")).get_or(Other(7))
