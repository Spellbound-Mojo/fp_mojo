# error: invalid call to 'map'
from fp.data import Ior, Right
from fp.algebra import map, IorFamily, StringMonoid
def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    def keep(var value: Span[Int, origin_of(left)]) -> Int: return value[0]
    _ = map[IorFamily[StringMonoid]](keep, Ior[String, Span[Int, origin_of(right)]](Right(Span(right))))
