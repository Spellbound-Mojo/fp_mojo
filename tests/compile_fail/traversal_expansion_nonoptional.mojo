# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ListFamily
def wrong(value: Int) -> Optional[Int]: return Optional(value)
def main():
    var xs: List[Int] = [1]
    _ = pipeline(xs^).traverse_filter[OptionalFamily](wrong)
