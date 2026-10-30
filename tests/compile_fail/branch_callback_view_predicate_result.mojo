# error: no matching function
from fp.functions import partial
from fp.iteration import partition, Unbounded
def add(offset: Int, value: Int) -> Int: return offset + value
def main():
    var predicate = partial(add, 1)
    _ = partition(range(3), predicate, buffer=Unbounded())
