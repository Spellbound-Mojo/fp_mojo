from fp.algebra import map, ResultFamily
# error: error: cannot implicitly convert
# error: value to 'Result[Span[Int, origin_of(second)], Int]'
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.os import abort

def identity[V: Movable & Deinitable](var value: V) -> V: return value^
def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    var subject = Result[A, Int](Ok(a))
    var mapped: Result[B, Int] = map[ResultFamily[type_of(subject).Error]](identity[A], subject^)
    _ = mapped^

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
