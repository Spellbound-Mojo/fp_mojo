"""Generic callbacks preserve exact native errors through terminal reduction."""
from fp.functions import pipeline
from fp.algebra import StringMonoid
from std.testing import assert_equal

def forward[A: Movable & Deinitable,E: Movable & Deinitable,//, F:def(var A) raises E -> Int](ref f:F,var xs:List[A]) raises E -> Int:
    return pipeline(xs^).raising[E]().sum_by(f).get()
def fold[A: Movable & Deinitable,E: Movable & Deinitable,//, F:def(var A) raises E -> String](ref f:F,var xs:List[A]) raises E -> String:
    return pipeline(xs^).raising[E]().fold_map[StringMonoid](f).get()
def choose[A: Movable & Deinitable,E: Movable & Deinitable,//, F:def(A) raises E -> Int](ref f:F,var xs:List[A]) raises E -> Optional[A]:
    return pipeline(xs^).raising[E]().max_by(f).get()
def search[A: Movable & Deinitable,E: Movable & Deinitable,//, F:def(var A) raises E -> Optional[A]](ref f:F,var xs:List[A]) raises E -> Optional[A]:
    return pipeline(xs^).raising[E]().find_map(f).get()
def main() raises:
    def f(var x: Int) raises Int -> Int:
        if x < 0: raise x
        return x
    var code = 0
    try: _ = forward(f,List[Int]([-1]))
    except e: code=e
    assert_equal(code,-1)
    def s(var x: Int) -> String: return String(x)
    assert_equal(fold(s,List[Int]([1,2])),"12")
    def key(x: String) -> Int: return x.byte_length()
    assert_equal(choose(key,List[String](["a","bbb"])).value(),"bbb")
    def find(var value:Int) raises Int -> Optional[Int]: raise value
    try: _ = search(find,List[Int]([7]))
    except error: code=error
    assert_equal(code,7)
