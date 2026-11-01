# error: invalid call to 'recover_if': lacking evidence to prove correctness
from fp.functions import pipeline
from fp.effects import Reader, ResultT
from fp.callables import OnceUnary, BorrowCallable
@fieldwise_init
struct Accept(BorrowCallable):
    comptime Payload = String
    comptime Result = Bool
    def invoke(self, error: String) -> Bool: return True
@fieldwise_init
struct Restore[V: Movable & Deinitable](OnceUnary):
    var value: Self.V
    comptime Arg = String
    comptime Out = Self.V
    def call_once(deinit self, var error: String) -> Self.V: return self.value^
def reject(left: List[Int], right: List[Int]):
    comptime I = ResultT[Reader[Int],String]
    comptime Left = type_of(Span(left))
    _ = pipeline[I](I.fail[Left](String("x"))).recover_if(Accept(),Restore(Span(right))).get()
def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    reject(left,right)
