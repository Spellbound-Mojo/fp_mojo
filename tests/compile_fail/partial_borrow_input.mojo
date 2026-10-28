# error: no matching method
from fp.functions import pipeline, partial

def long(limit: Int, value: String) -> Bool: return value.byte_length() > limit
def main():
    var predicate = partial(long, 2)
    _ = pipeline[Int]([1, 2]).filter(predicate)
