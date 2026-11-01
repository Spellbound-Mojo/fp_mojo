# error: origin_of(local)
from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result
def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    var expected = Span(anchor)
    comptime Local = type_of(actual)
    def project(var value: Int) {actual} -> Local: return actual
    var result: List[type_of(expected)] = piped(List[Int]([1])).map(project).get()
    _ = result^
def main():
    var anchor: List[Int] = [1]
    var local: List[Int] = [2]
    check(anchor, local)
