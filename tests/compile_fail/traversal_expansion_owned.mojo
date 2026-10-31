# error: no matching method in call to 'filter_effect'
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ListFamily
def wrong(var value: String) -> Optional[Bool]: return Optional(True)
def main():
    var xs: List[String] = [String("one")]
    _ = pipeline(xs^).filter_effect[OptionalFamily](wrong)
