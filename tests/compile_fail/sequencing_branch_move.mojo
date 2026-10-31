# error: repeatable
from fp.functions import pipeline
@fieldwise_init
struct SeqOwner(Movable):
    var value: Int
def choices(value: SeqOwner) -> List[Int]: return List[Int]([1,2])
def main():
    var values = List[SeqOwner]()
    values.append(SeqOwner(1))
    _ = pipeline(values^).flat_tap(choices)
