# error: invalid call to 'traverse'
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
    def callback(var value: Int) {actual} -> Result[Int, Local]: return Err(actual)
    _ = pipeline(List[Int]([1])).traverse[ResultFamily[Expected]](callback).get()
def main():
    var anchor: List[Int] = [1]
    var local: List[Int] = [2]
    check(anchor, local)
