# error: pipe: stage 0 must take one argument: a Unary value, or a native function promoted with as_unary
from fp.functions import pipe, as_unary
from std.builtin.variadics import TypeList
def inc(var value: Int) -> Int: return value + 1
def main():
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Int]()
    _ = pipe[Path](1, inc)
