# error: no matching function
from fp.functions import partial
from fp.iteration import partition_map, Unbounded
from fp.data import Result
def fail(offset: Int, value: Int) raises Int -> Result[Int, Int]: raise offset + value
def main():
    var classifier = partial(fail, 1)
    _ = partition_map(classifier, range(3), buffer=Unbounded())
