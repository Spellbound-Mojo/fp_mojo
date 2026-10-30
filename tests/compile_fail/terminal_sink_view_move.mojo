# error: use of uninitialized value 'sink'
from fp.functions import partial
from fp.iteration import for_each
def observe(prefix: Int, value: Int) -> NoneType:
    _ = prefix
    _ = value
    return None
def main():
    var sink = partial(observe, 1)
    for_each(range(3), sink^)
    for_each(range(3), sink)
