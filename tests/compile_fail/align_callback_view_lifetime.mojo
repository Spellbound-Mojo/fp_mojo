# error: use of uninitialized value 'project'
from fp.functions import partial
from fp.iteration import align_with, iterated
from fp.data import Ior, Left
def constant(offset: Int, value: Ior[Int, Int]) -> Int:
    _ = value
    return offset
def main():
    var project = partial(constant, 1)
    var pending = align_with(range(2), range(3), project)
    var moved = project^
    var value: Ior[Int, Int] = Left(0)
    _ = moved(value)
    _ = iterated(pending^).collect_list()
