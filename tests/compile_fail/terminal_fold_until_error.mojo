# error: invalid call to 'fold_until': lacking evidence to prove correctness
from fp.iteration import fold_left, reduce, reduce_optional, fold_until
from fp.iteration import find, any, all
from fp.data import ControlFlow, Continue
from std.iter import iter

def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    def step(var acc: A, var item: Int) raises B -> ControlFlow[A, A]: return ControlFlow[A, A](Continue(acc))
    try:
        _ = fold_until[A=A, B=A, E=A](step, a, iter(range(1)))
    except: pass

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
