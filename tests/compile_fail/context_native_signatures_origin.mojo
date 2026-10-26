# error: no matching method
from fp.functions import pipeline
def check(left:List[Int],right:List[Int]):
    comptime View=type_of(Span(left))
    def first(var value:View)->Int: return len(value)
    var pointer:def(var View) thin ->Int=first
    _ = pipeline(Optional(Span(right))).map(pointer).get()
def main(): check(List[Int]([1]),List[Int]([2]))
