# error: cannot implicitly convert
from fp.data import Capture, Result
@fieldwise_init
struct Actual(Movable):
    var value: Int
@fieldwise_init
struct Other(Movable):
    var value: Int

def target(var **values: Int) raises Actual -> Int:
    raise Actual(7)

def main():
    var result: Result[Int, Other] = Capture.kwargs(one=7).run(target)
