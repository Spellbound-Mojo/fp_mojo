# error: no matching method
from fp.functions import piped
from fp.algebra import OptionalFamily, ListFamily
def wrong(var value: String) -> Optional[Bool]: return Optional(True)
def main():
    var xs: List[String] = [String("one")]
    _ = piped(xs^).filter_effect[OptionalFamily](wrong)
