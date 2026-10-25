# error: origin_of(local)
from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result
def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    var expected = Span(anchor)
    comptime Local = type_of(actual)
    def fail() raises Local {actual} -> Int: raise actual
    var result: Result[Int, type_of(expected)] = Capture[Local]().run(fail)
    _ = result^
def main():
    var anchor: List[Int] = [1]
    var local: List[Int] = [2]
    check(anchor, local)
