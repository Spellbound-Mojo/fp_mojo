# error: no matching method
from fp.data import Capture
@fieldwise_init
struct Fault(Movable):
    var code: Int
@fieldwise_init
struct Other(Movable):
    var code: Int
def f(var value: Int) raises Fault -> Int:
    raise Fault(value)
def main():
    var pointer: def(var Int) raises Fault thin -> Int = f
    _ = Capture[Other].args(1).run(pointer)
