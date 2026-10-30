# error: constraint failed: find_map: Optional result required
from fp.functions import partial
from fp.iteration import find_map
def add(offset: Int, value: Int) -> Int: return value + offset
def main():
    var project = partial(add, 1)
    _ = find_map(range(3), project)
