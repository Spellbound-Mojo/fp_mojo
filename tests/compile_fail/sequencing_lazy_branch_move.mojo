# error: repeatable
from fp.iteration import iterated
@fieldwise_init
struct SeqOwner(Movable):
    var value: Int
def choices(value: SeqOwner) -> List[Int]: return List[Int]([1,2])
def main():
    var values = List[SeqOwner]()
    values.append(SeqOwner(1))
    _ = iterated(values^).flat_tap(choices).to_list()
