# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
from fp.algebra import StringMonoid
def number(offset: Int, value: Int) -> Optional[Int]: return Optional(offset + value)
def main():
    var project = partial(number, 1)
    _ = iterated(range(3)).collect_fold[StringMonoid](project)
