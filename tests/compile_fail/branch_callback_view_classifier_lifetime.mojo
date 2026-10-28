# error: use of uninitialized value 'classifier'
from fp.functions import partial
from fp.iteration import partition_map, Unbounded
from fp.data import Result, Ok
from fp.callables.products import _take_pair
from std.memory import MaybeUninit
from std.iter import next
def classify(offset: Int, value: Int) -> Result[Int, Int]: return Ok(offset + value)
def main() raises:
    var classifier = partial(classify, 1)
    var branches = partition_map(classifier, range(3), buffer=Unbounded())
    var first = MaybeUninit[type_of(branches[0])]()
    var second = MaybeUninit[type_of(branches[1])]()
    _take_pair(branches^, first, second)
    var remaining = first^.unsafe_assume_init()
    _ = second^.unsafe_assume_init()
    var moved = classifier^
    _ = moved(1)
    _ = next(remaining)
