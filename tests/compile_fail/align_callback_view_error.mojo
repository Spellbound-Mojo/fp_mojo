# error: no matching
from fp.functions import partial
from fp.iteration import iterated
from fp.data import Ior
def fail(offset: Int, value: Ior[Int, Int]) raises Int -> Int:
    _ = value
    raise offset
def main():
    var project = partial(fail, 1)
    _ = iterated(range(2)).align_with(range(3), project)
