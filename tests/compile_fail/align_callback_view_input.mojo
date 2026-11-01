# error: no matching function
from fp.functions import partial
from fp.iteration import align_with
def wrong(offset: Int, value: Int) -> Int: return offset + value
def main():
    var project = partial(wrong, 1)
    _ = align_with(range(2), range(3), project)
