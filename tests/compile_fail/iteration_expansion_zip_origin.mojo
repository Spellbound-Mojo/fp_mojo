# error: origin_of(local)
from fp.iteration import iterated
from std.iter import iter
def check(anchor: List[Int]):
    var local: List[Int] = [1,2]
    var expected = iterated(iter(anchor)).zip(iter(anchor))
    var actual = iterated(iter(anchor)).zip(iter(local))
    expected = actual^
def main():
    var anchor: List[Int] = [1,2]
    check(anchor)
