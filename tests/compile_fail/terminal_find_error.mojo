# error: invalid call to 'find': lacking evidence to prove correctness
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
    def step(value: A) raises B -> Bool: return True
    try:
        _ = find[T=A, E=A](step, iter(List[A]()))
    except: pass

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
