# error: no matching function
from fp.functions import partial
from fp.iteration import filter_map
def add(offset: Int, value: Int) -> Int: return offset + value
def main():
    var project = partial(add, 1)
    _ = filter_map(project, range(3))
