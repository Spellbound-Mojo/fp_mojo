# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def key(offset: Int, value: Int) -> List[Int]: return List[Int]([offset, value])
def main():
    var project = partial(key, 1)
    _ = iterated(range(3)).max_by(project)
