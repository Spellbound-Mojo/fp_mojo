# error: pipe: stage 0 should take Int, return Int
# error: it takes Int, returns String
from fp.functions import pipe, as_unary
from std.builtin.variadics import TypeList
def text(var value: Int) -> String: return String(value)
def main():
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Int]()
    var a = as_unary(text)
    _ = pipe[Path](1, a)
