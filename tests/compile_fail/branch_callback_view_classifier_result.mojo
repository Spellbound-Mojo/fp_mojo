# error: no matching method
from fp.functions import partial
from fp.iteration import iterated, Unbounded
def optional(offset: Int, value: Int) -> Optional[Int]: return Optional(offset + value)
def main():
    var classifier = partial(optional, 1)
    _ = iterated(range(3)).partition_map(classifier, buffer=Unbounded())
