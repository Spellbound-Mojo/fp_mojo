# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def observe(prefix: String, value: String) -> NoneType:
    _ = prefix
    _ = value
    return None
def main():
    var sink = partial(observe, String("#"))
    iterated(range(3)).for_each(sink)
