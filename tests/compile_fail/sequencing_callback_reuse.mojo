# error: uninitialized
from fp.iteration import iterated
def main():
    var state = List[Int]([0])
    def make() {var state^} -> List[Int]:
        state[0] += 1
        return List[Int]([state[0]])
    var pending = iterated(range(2)).before(make^)
    _ = make()
    _ = pending^.to_list()
