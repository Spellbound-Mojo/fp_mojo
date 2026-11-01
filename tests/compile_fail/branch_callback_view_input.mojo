# error: no matching function
from fp.functions import partial
from fp.iteration import partition_map, Unbounded
from fp.data import Result, Ok
def classify(offset: Int, value: String) -> Result[Int, Int]: return Ok(offset + value.byte_length())
def main():
    var classifier = partial(classify, 1)
    _ = partition_map(range(3), classifier, buffer=Unbounded())
