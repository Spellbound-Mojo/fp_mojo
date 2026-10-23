# error: repeatable
from fp.functions import piped
@fieldwise_init
struct SeqPairOwner(Movable):
    var value: Int
def choices(value: SeqPairOwner) -> List[Int]: return List[Int]([1,2])
def main():
    var values = List[SeqPairOwner]()
    values.append(SeqPairOwner(1))
    _ = piped(values^).flat_pair_with(choices)
