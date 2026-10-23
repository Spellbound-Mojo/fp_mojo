# error: origin_of(local)
from fp.iteration import iterated
from std.iter import iter
def predicate(value: Int) -> Bool: return value > 0
def check(anchor: List[Int]):
    var local: List[Int] = [1,2]
    var expected = iterated(iter(anchor)).take_while(predicate)
    var actual = iterated(iter(local)).take_while(predicate)
    expected = actual^
def main():
    var anchor: List[Int] = [1,2]
    check(anchor)
