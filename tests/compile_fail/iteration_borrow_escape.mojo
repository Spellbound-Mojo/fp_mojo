# error: origin_of(local)
from fp.iteration import flatten
from std.iter import iter, once

def borrowed(values: List[Int]) -> List[Int].IteratorType[origin_of(values)]:
    return values.__iter__()

def escape(ref anchor: List[Int]) -> type_of(flatten(once(borrowed(anchor)))):
    var local: List[Int] = [1, 2]
    return flatten(once(borrowed(local)))

def main() raises:
    var anchor: List[Int] = []
    var value = escape(anchor)
    print(value.__next__())
