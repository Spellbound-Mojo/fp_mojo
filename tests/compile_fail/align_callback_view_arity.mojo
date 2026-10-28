# error: no matching function
from fp.functions import partial
from fp.iteration import align_with
def complete(value: Int) -> Int: return value
def main():
    var project = partial(complete, 1)
    _ = align_with(project, range(2), range(3))
