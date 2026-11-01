# error: cannot implicitly convert
from fp.data import Result, ok
@fieldwise_init
struct Expected(Movable):
    var code: Int
@fieldwise_init
struct Other(Movable):
    var code: Int
def main():
    var bad: Result[Int, Expected] = ok[Other](1)
    _ = bad^
