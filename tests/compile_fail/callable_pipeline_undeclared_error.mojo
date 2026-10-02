# error: pipe: stage 0 should take Int, return Int and raise nothing
# error: raises std.builtin.error.Error
from fp.functions import pipe, as_unary
from std.builtin.variadics import TypeList
def fail(var value: Int) raises Error -> Int: raise Error(String(value))
def main():
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Int]()
    var a = as_unary(fail)
    _ = pipe[Path](1, a)
