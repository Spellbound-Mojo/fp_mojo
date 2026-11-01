# error: constraint
from fp.functions import pipeline
from fp.algebra import OptionalFamily
def wrong(a: Int,b: Int) -> Optional[String]: return Optional(String("bad"))
def main():
    var xs: List[Int] = [1]
    _ = pipeline(xs^).fold_effect[OptionalFamily](0).run(wrong)
