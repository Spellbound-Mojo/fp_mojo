# error: constraint
from fp.iteration import iterated
from fp.algebra import OptionalFamily
def wrong(x: Int) -> Optional[Int]: return Optional(x)
def main(): _ = iterated(range(3)).any_effect[OptionalFamily](wrong)
