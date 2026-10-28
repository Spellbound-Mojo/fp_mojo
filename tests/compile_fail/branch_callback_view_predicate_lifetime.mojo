# error: use of uninitialized value 'predicate'
from fp.functions import partial
from fp.iteration import partition, Unbounded
from std.iter import next
def below(limit: Int, value: Int) -> Bool: return value < limit
def main() raises:
    var predicate = partial(below, 2)
    var branches = partition(predicate, range(3), buffer=Unbounded())
    var moved = predicate^
    _ = moved(1)
    _ = next(branches[0])
