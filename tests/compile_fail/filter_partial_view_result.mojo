# error: no matching method
from fp.functions import partial
from fp.iteration import iterated

def add(offset: Int, value: Int) -> Int: return offset + value
def main():
    var predicate = partial(add, 2)
    _ = iterated(range(3)).filter(predicate)
