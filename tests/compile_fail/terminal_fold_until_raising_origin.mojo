# error: invalid call to 'fold_until': lacking evidence to prove correctness
# error: origin_of(local)
from fp.iteration import fold_until
from fp.data import ControlFlow, Break
from std.iter import iter

def escape(first: List[Int]) raises Error -> Span[Int, origin_of(first)]:
    var local: List[Int] = [22]
    var a = Span(first)
    var b: Span[Int, ImmOrigin(origin_of(local))] = Span(local)
    comptime A = type_of(a)
    comptime B = type_of(b)
    def step(var acc: A, var item: Int) raises Error {b} -> ControlFlow[B, A]:
        return ControlFlow[B, A](Break(b))
    var result = fold_until[A=A, B=A](step, a, iter(range(1)))
    return result^.unwrap[Break[A]]().into_payload()

def main() raises:
    var first: List[Int] = [11]
    _ = escape(first)
