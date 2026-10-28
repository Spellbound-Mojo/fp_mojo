# error: no matching function
from fp.functions import partial
from fp.iteration import count_where
def long(limit: Int, value: String) -> Bool: return value.byte_length() > limit
def main():
    var predicate = partial(long, 1)
    _ = count_where(predicate, range(3))
