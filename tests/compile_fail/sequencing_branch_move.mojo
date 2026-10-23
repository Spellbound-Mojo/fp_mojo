# error: repeatable
from fp.functions import piped
@fieldwise_init
struct SeqOwner(Movable):
    var value: Int
def choices(value: SeqOwner) -> List[Int]: return List[Int]([1,2])
def main():
    var values = List[SeqOwner]()
    values.append(SeqOwner(1))
    _ = piped(values^).flat_tap(choices)
