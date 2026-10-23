# error: cannot implicitly convert
from fp.functions import piped

def main() raises:
    var anchor: List[Int] = [10, 20]
    def outer(value: Int) {ref anchor} -> Span[Int, origin_of(anchor)]:
        return Span(anchor)
    var xs: List[Int] = [1]
    var expected = piped(xs^).map(outer).get()
    var local: List[Int] = [30, 40]
    def inner(value: Int) {ref local} -> Span[Int, origin_of(local)]:
        return Span(local)
    var ys: List[Int] = [1]
    expected = piped(ys^).map(inner).get()
    _ = expected^
