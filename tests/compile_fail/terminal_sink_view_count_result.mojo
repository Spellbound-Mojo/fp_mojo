# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def number(offset: Int, value: Int) -> Int: return offset + value
def main():
    var predicate = partial(number, 1)
    _ = iterated(range(3)).count_where(predicate)
