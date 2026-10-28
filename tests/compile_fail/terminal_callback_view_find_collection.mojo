# error: constraint failed: find_map: Optional result required
from fp.functions import partial, piped
def collect(offset: Int, value: Int) -> List[Int]: return List[Int]([offset + value])
def main():
    var project = partial(collect, 1)
    _ = piped(List[Int]([1, 2])).find_map(project).get()
