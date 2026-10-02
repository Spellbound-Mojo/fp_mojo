# error: invalid call to 'fold': lacking evidence to prove correctness
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.os import abort

def read_count[V: Movable & Deinitable](value: V) -> Int: return 1
def read_raising[V: Movable & Deinitable, E: Movable & Deinitable](value: V) raises E -> Int: return 1
def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    var subject = Result[Int, Int](Ok(1))
    try:
        _ = subject.fold[R=Int, X=A](read_raising[Int, B], read_count[Int])
    except: pass

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
