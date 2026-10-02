# error: aliasing values passed mutably
from fp.functions import pipe, as_unary
from std.builtin.variadics import TypeList
def main():
    var calls = 0
    def count(var value: Int) {mut calls} -> Int:
        calls += 1
        return value + calls
    var a = as_unary(count)
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Int, Int]()
    _ = pipe[Path](1, a, a)
