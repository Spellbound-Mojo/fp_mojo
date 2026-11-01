# error: invalid call to 'map'
from fp.data import NonEmptyList
from fp.algebra import map, NonEmptyListFamily
def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    def keep(var value: Span[Int, origin_of(left)]) -> Int: return value[0]
    _ = map[NonEmptyListFamily](NonEmptyList(Span(right)), keep)
