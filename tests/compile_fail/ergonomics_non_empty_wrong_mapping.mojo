# error: no matching
from fp.iteration import reduce_map
from fp.data import NonEmptyList
from fp.algebra import StringMonoid
def wrong(var a: Int) -> Int: return a
def main(): _ = reduce_map[StringMonoid](NonEmptyList(1), wrong)
