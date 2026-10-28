# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def observe(prefix: Int, first: Int, second: Int) -> NoneType:
    _ = prefix
    _ = first
    _ = second
    return None
def main():
    var sink = partial(observe, 1)
    iterated(range(3)).for_each(sink)
