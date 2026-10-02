# error: cannot implicitly convert
# error: Actual
# error: Other
from fp.data import Result, attempt
@fieldwise_init
struct Actual(Movable):
    var code: Int
@fieldwise_init
struct Other(Movable):
    var code: Int

def fail(value: Int) raises Actual -> Int: raise Actual(value)
def main():
    var result: Result[Int, Other] = attempt(fail, 42)
    _ = result^
