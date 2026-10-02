# error: invalid call to 'fold_owned': lacking evidence to prove correctness
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.os import abort

def identity[V: Movable & Deinitable](var value: V) -> V: return value^
def identity_raising[V: Movable & Deinitable, E: Movable & Deinitable](var value: V) raises E -> V: return value^
def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    var subject = Result[A, A](Ok(a))
    try:
        _ = subject^.fold_owned[R=B, X=Int](identity[A], identity_raising[A, Int])
    except: pass

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
