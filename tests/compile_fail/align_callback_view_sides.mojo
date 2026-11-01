# error: no matching
from fp.functions import partial
from fp.iteration import iterated
from fp.data import Ior
def wrong(offset: Int, value: Ior[String, Int]) -> Int:
    _ = value
    return offset
def main():
    var project = partial(wrong, 1)
    var other: List[String] = ["right"]
    _ = iterated(range(2)).align_with(other^, project)
