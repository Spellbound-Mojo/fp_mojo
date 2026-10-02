# error: pipe: stage 1 should take String
# error: it takes Int
from fp.functions import pipe, as_unary
from std.builtin.variadics import TypeList
def text(var value: Int) -> String: return String(value)
def length(var value: Int) -> Int: return value
def main():
    comptime Path = TypeList.of[Trait=Movable & Deinitable, String, Int]()
    var a = as_unary(text)
    var b = as_unary(length)
    _ = pipe[Path](1, a, b)
