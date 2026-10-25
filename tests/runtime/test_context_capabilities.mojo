from fp.functions import pipeline
from std.testing import assert_equal

def double(var value: Int) -> List[Int]: return List[Int]([value, value])
def present(var value: Int) -> Optional[String]:
    if value > 1: return Optional(String(value))
    return Optional[String]()
def main() raises:
    assert_equal(pipeline(List[Int]([1,2])).flat_map(double).get(), List[Int]([1,1,2,2]))
    assert_equal(pipeline(List[Int]([1,2])).filter_map(present).get(), List[String](["2"]))
