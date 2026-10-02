from fp.algebra import flat_map, ResultFamily
# error: error: cannot implicitly convert
# error: value to 'Result[Span[Int, origin_of(second)], Int]'
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.os import abort

def keep_raising[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable](var value: T) raises X -> Result[T, E]: return Result[T, E](Ok(value^))
def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    var subject = Result[A, Int](Ok(a))
    try:
        var sequenced: Result[B, Int] = flat_map[ResultFamily[type_of(subject).Error], X=B](keep_raising[A, Int, B], subject^)
        _ = sequenced^
    except: pass

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
