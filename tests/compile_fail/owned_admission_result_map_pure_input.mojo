from fp.algebra import map, ResultFamily
# error: invalid call to 'map': lacking evidence to prove correctness
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.os import abort

def count[V: Movable & Deinitable](var value: V) -> Int: return 1
def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    var subject = Result[A, Int](Ok(a))
    _ = map[ResultFamily[type_of(subject).Error]](count[B], subject^)

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
