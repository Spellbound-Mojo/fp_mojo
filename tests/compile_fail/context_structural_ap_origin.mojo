# error: lacking evidence
from fp.functions import pipeline
from fp.callables import Unary
@fieldwise_init
struct Size[T:Movable & Deinitable](Unary):
    comptime Arg=Self.T
    comptime Out=Int
    def call(self,var value:Self.T)->Int: return 1
def check(left:List[Int],right:List[Int]):
    comptime L=type_of(Span(left))
    _ = pipeline(Optional(Size[L]())).ap(Optional(Span(right))).get()
def main(): check(List[Int]([1]),List[Int]([2]))
