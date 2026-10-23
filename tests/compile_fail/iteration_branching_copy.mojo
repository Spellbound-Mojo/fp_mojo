# error: cannot be implicitly copied
from fp.iteration import partition, Unbounded
from std.iter import Iterator, next
def i3_predicate(value: Int) -> Bool: return value > 0
def consume[I: Iterator](var branch: I): pass
def main() raises:
    var branches = partition(i3_predicate, range(3), buffer=Unbounded())
    consume(branches[0])
    _ = next(branches[0])
