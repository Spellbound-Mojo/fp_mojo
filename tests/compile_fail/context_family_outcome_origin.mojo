# error: invalid call to 'redeem': lacking evidence to prove correctness
from fp.functions import pipeline
from fp.effects import Reader, ResultT
from fp.callables import OnceUnary
@fieldwise_init
struct Return[V: Movable & Deinitable, A: Movable & Deinitable](OnceUnary):
    var value: Self.V
    comptime Arg = Self.A
    comptime Out = Self.V
    def call_once(deinit self, var input: Self.A) -> Self.V: return self.value^
def reject(left: List[Int], right: List[Int]):
    comptime I = ResultT[Reader[Int],String]
    comptime L = type_of(Span(left))
    comptime R = type_of(Span(right))
    _ = pipeline[I](I.pure(1)).redeem(Return[L,Int](Span(left)),Return[R,String](Span(right))).get()
def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    reject(left,right)
