# error: invalid call to 'fold': lacking evidence to prove correctness
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.os import abort

def copied[V: Copyable & Deinitable](value: V) -> V: return value.copy()
def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    var subject = Result[A, A](Ok(a))
    _ = subject.fold[R=B](copied[A], copied[A])

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
