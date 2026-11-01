# error: origin_of(local)
from fp.functions import pipeline
def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    comptime Actual = type_of(actual)
    def project(value: Int) {actual} -> Actual: return actual
    var output: List[Tuple[Int,type_of(Span(anchor))]] = pipeline(List[Int]([1])).pair_with(project).get()
    _ = output^
def main():
    var anchor = List[Int]([1])
    var local = List[Int]([2])
    check(anchor,local)
