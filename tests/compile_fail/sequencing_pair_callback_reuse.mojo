# error: uninitialized
from fp.iteration import iterated
def main():
    var state = List[Int]([0])
    def project(value: Int) {var state^} -> List[Int]:
        state[0] += 1
        return List[Int]([state[0]+value])
    var pending = iterated(range(2)).flat_pair_with(project^)
    _ = project(1)
    _ = pending^.to_list()
