# error: origin_of(local)
from fp.iteration import partition, Unbounded
from std.iter import iter
def i3_predicate(value: Int) -> Bool: return value > 0
def check(anchor: List[Int]):
    var local: List[Int] = [1,2]
    var expected = partition(i3_predicate, iter(anchor), buffer=Unbounded())
    var actual = partition(i3_predicate, iter(local), buffer=Unbounded())
    expected = actual^
def main():
    var anchor: List[Int] = [1,2]
    check(anchor)
