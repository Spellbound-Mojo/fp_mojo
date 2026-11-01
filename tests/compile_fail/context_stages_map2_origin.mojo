# error: invalid call to 'map2'
# error: origin_of(local)
# error: origin_of(anchor)
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.algebra import ResultFamily

def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    var expected = Span(anchor)
    comptime Local = type_of(actual)
    comptime Expected = type_of(expected)
    def callback(var a: Int, var b: Int) -> Int: return a + b
    _ = pipeline(Result[Int, Expected](Err(expected))).map2(Result[Int, Local](Err(actual)), callback).get()
def main():
    var anchor: List[Int] = [1]
    var local: List[Int] = [2]
    check(anchor, local)
