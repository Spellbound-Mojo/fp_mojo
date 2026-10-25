# error: lacking evidence to prove correctness
# error: origin_of(local)
from fp.control import scan
from fp.iteration import scan_map

def check(anchor: List[Int]) raises:
    var local: List[Int] = [22]
    var expected = Span(anchor)
    var actual: Span[Int, ImmOrigin(origin_of(local))] = Span(local)
    comptime Expected = type_of(expected)
    comptime Actual = type_of(actual)
    def step(var carry: Expected, var item: Int) {actual} -> Tuple[Actual, Int]:
        return (actual, item)
    _ = scan_map[Y=Int](step, expected, range(1))

def main() raises:
    var anchor: List[Int] = [11]
    check(anchor)
