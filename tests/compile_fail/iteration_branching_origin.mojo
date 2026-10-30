# error: origin_of(local)
from fp.iteration import partition, Unbounded
from std.iter import iter
def i3_predicate(value: Int) -> Bool: return value > 0
def check(anchor: List[Int]):
    var local: List[Int] = [1,2]
    var expected = partition(iter(anchor), i3_predicate, buffer=Unbounded())
    var actual = partition(iter(local), i3_predicate, buffer=Unbounded())
    expected = actual^
def main():
    var anchor: List[Int] = [1,2]
    check(anchor)
