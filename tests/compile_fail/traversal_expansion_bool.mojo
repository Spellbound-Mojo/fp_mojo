# error: constraint
from fp.functions import piped
from fp.algebra import OptionalFamily, ListFamily
def wrong(value: Int) -> Optional[Int]: return Optional(value)
def main():
    var xs: List[Int] = [1]
    _ = piped(xs^).filter_effect[OptionalFamily](wrong)
