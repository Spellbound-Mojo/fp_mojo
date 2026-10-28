# error: use of uninitialized value 'project'
from fp.functions import as_unary
from fp.iteration import iterated
from fp.data import Ior, Left
def constant(var value: Ior[Int, Int]) -> Int:
    _ = value^
    return 1
def main():
    var project = as_unary(constant)
    var pending = iterated(range(2)).align_with(range(3), project)
    var moved = project^
    var value: Ior[Int, Int] = Left(0)
    _ = moved.call(value^)
    _ = pending^.collect_list()
