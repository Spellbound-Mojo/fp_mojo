# error: cannot implicitly convert
from fp.data import ok
from fp.functions import pipeline
@fieldwise_init
struct Token(Movable):
    var value: Int
@fieldwise_init
struct Other(Movable):
    var value: Int
def wrong() -> Other:
    return pipeline(ok[Never](Token(3))).raise_on_err()
def main():
    _ = wrong()
