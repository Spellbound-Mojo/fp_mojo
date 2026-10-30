# error: constraint
from fp.iteration import fold_map_effect
from fp.algebra import OptionalFamily, StringMonoid
def wrong(var value:Int)->Optional[Int]:return Optional(value)
def main(): _=fold_map_effect[OptionalFamily,StringMonoid](range(3),wrong)
