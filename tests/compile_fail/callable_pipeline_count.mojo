# error: pipe: one result type is required per stage
from fp.functions import pipe, as_unary
from std.builtin.variadics import TypeList
def inc(var value: Int) -> Int: return value + 1
def main():
    comptime Empty = TypeList.of[Trait=Movable & Deinitable]()
    var a = as_unary(inc)
    _ = pipe[Empty](1, a)
