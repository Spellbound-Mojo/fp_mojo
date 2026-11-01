# error: lacking evidence
from fp.functions import pipeline
def check(left:List[Int],right:List[Int]):
    comptime L=type_of(Span(left))
    comptime R=type_of(Span(right))
    var a=Span(left)
    var b=Span(right)
    def first() {a}->Optional[L]: return Optional(a)
    def second() {b}->Optional[R]: return Optional(b)
    _ = pipeline(Optional(True)).if_effect(first,second).get()
def main(): check(List[Int]([1]),List[Int]([2]))
