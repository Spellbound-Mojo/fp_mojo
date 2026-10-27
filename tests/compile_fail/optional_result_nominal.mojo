# error: cannot implicitly convert
from fp.functions import pipeline
from fp.data import Result
@fieldwise_init
struct Token(Movable):
    var value: Int
@fieldwise_init
struct Other(Movable):
    var value: Int
def factory() -> Other: return Other(7)
def main():
    var bad: Result[Int, Token] = pipeline(Optional(1)).to_result(factory).get()
    _ = bad^
