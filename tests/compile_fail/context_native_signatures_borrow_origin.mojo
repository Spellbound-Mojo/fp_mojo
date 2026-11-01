# error: lacking evidence
from fp.functions import pipeline
def check(left:List[Int],right:List[Int]):
    comptime View=type_of(Span(left))
    def first(value:View)->Int: return len(value)
    var pointer:def(View) thin ->Int=first
    _ = pipeline(Optional(Span(right))).pair_with(pointer).get()
def main(): check(List[Int]([1]),List[Int]([2]))
