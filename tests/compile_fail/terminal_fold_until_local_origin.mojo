# error: invalid call to 'fold_until': lacking evidence to prove correctness
# error: origin_of(local)
from fp.iteration import fold_until
from fp.data import ControlFlow, Break
from std.iter import iter

def escape(first: List[Int]) -> Span[Int, origin_of(first)]:
    var local: List[Int] = [22]
    var a = Span(first)
    var b: Span[Int, ImmOrigin(origin_of(local))] = Span(local)
    comptime A = type_of(a)
    comptime B = type_of(b)
    def step(var acc: A, var item: Int) {b} -> ControlFlow[B, A]:
        return ControlFlow[B, A](Break(b))
    var result = fold_until[A=A, B=A](iter(range(1)), a, step)
    return result^.unwrap[Break[A]]().into_payload()

def main():
    var first: List[Int] = [11]
    _ = escape(first)
