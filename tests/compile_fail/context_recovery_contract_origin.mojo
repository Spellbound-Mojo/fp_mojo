# error: invalid call to 'recovered': lacking evidence to prove correctness
from fp.algebra import ApplicativeError
from fp.algebra.contracts import RecoverContract
from fp.callables import UnaryContract
from fp.functions import pipeline

def recovered[I: ApplicativeError, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var handler: H) raises RecoverContract[I,V,H].Error -> RecoverContract[I,V,H].Out where RecoverContract[I,V,H].Compatible:
    return pipeline(source^).recover[I](handler^).get()

from fp.callables import OnceUnary
from fp.algebra import ResultFamily, fail
@fieldwise_init
struct Restore[V: Movable & Deinitable](OnceUnary):
    var value: Self.V
    comptime Arg = String
    comptime Out = Self.V
    def call_once(deinit self, var error: String) -> Self.V: return self.value^
def reject(left: List[Int], right: List[Int]):
    comptime Left = type_of(Span(left))
    _ = recovered[ResultFamily[String]](fail[ResultFamily[String], Left](String("x")), Restore(Span(right)))
def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    reject(left,right)
