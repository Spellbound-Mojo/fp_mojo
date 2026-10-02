# error: invalid call to 'map_err': lacking evidence to prove correctness
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.os import abort

def identity_raising[V: Movable & Deinitable, E: Movable & Deinitable](var value: V) raises E -> V: return value^
def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    var subject = Result[Int, A](Err(a))
    try:
        _ = subject^.map_err[U=B, X=B](identity_raising[A, B])
    except: pass

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
