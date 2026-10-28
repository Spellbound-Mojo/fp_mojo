# error: no matching method
from fp.functions import pipeline, partial

def add(offset: Int, value: Int) -> Int: return offset + value
def main():
    var predicate = partial(add, 2)
    _ = pipeline[Int]([1, 2]).filter(predicate)
