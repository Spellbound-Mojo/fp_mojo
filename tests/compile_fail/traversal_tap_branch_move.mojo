# error: repeatable
from fp.functions import pipeline
from fp.algebra import ListFamily
@fieldwise_init
struct TTBranchOwner(Movable):
    var value: Int
def choices(value: TTBranchOwner) -> List[Int]: return [value.value, value.value + 1]
def main():
    _ = pipeline(Optional(TTBranchOwner(1))).traverse_tap[ListFamily](choices)
