# error: no matching method
from fp.functions import partial
from fp.iteration import iterated

def long(limit: Int, value: String) -> Bool: return value.byte_length() > limit
def main():
    var predicate = partial(long, 2)
    _ = iterated(range(3)).filter(predicate)
