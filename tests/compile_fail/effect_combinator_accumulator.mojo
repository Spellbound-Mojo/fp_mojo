# error: constraint
from fp.functions import piped
from fp.algebra import OptionalFamily
def wrong(a: Int,b: Int) -> Optional[String]: return Optional(String("bad"))
def main():
    var xs: List[Int] = [1]
    _ = piped(xs^).fold_effect[OptionalFamily](wrong,0)
