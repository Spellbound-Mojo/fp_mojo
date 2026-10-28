# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def select(offset: Int, value: Int) -> Optional[Int]: return Optional(offset + value)
def main():
    var project = partial(select, 1)
    _ = iterated(range(3)).filter_map[U=String](project)
