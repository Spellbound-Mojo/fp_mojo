# error: constraint
from fp.iteration import find_map_effect
from fp.algebra import OptionalFamily
def wrong(var value:Int)->Optional[Int]:return Optional(value)
def main(): _=find_map_effect[OptionalFamily](range(3),wrong)
