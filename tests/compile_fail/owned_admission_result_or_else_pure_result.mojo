# error: invalid call to 'or_else': lacking evidence to prove correctness
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.os import abort

def recover[T: Movable & Deinitable, E: Movable & Deinitable](var value: E) -> Result[T, E]: return Result[T, E](Err(value^))
def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    var subject = Result[Int, A](Err(a))
    _ = subject^.or_else[U=B](recover[Int, A])

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
