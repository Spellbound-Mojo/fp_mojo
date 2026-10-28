# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def fail(offset: Int, value: Int) raises Int -> Optional[Int]: raise offset + value
def main():
    var project = partial(fail, 1)
    _ = iterated(range(3)).filter_map(project)
