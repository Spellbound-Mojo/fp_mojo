# error: no matching function
from fp.functions import partial
from fp.iteration import for_each
def number(offset: Int, value: Int) -> Int: return offset + value
def main():
    var sink = partial(number, 1)
    for_each(sink, range(3))
