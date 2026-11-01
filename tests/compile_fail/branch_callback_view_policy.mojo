# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def below(limit: Int, value: Int) -> Bool: return value < limit
def main():
    var predicate = partial(below, 2)
    _ = iterated(range(3)).partition(predicate)
