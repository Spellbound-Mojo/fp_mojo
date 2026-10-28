# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def values(offset: Int, value: Int) -> List[Int]: return List[Int]([offset + value])
def main():
    var project = partial(values, 1)
    _ = iterated(range(3)).filter_map(project)
