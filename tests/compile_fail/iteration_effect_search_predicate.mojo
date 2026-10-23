# error: constraint
from fp.iteration import find_effect
from fp.algebra import OptionalFamily
def wrong(value:Int)->Optional[Int]:return Optional(value)
def main(): _=find_effect[OptionalFamily](wrong,range(3))
