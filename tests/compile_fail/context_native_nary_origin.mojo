# error: no matching method
from fp.functions import pipeline
def check(left: List[Int], right: List[Int]):
    comptime Left = type_of(Span(left))
    def wrong(var a: Left, var b: String, var c: Int) -> Int: return c
    var pointer: def(var Left, var String, var Int) thin -> Int = wrong
    _ = pipeline(Optional(Span(right))).map_n((Optional(String("x")), Optional(2)), pointer).get()
def main(): check(List[Int]([1]), List[Int]([2]))
