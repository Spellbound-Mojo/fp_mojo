# error: repeatable
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.callables import BorrowOnceCallable
from fp.functions import pipeline
from fp.data import Result, Ok
@fieldwise_init
struct OnceObserver(BorrowOnceCallable):
    comptime Payload = Result[Int, String]
    comptime Result = List[Result[Int, String]]
    def invoke_once(deinit self, ref value: Self.Payload) raises Never capturing -> Self.Result:
        return [Result[Int, String](Ok(0))]
def main():
    comptime F = ResultT[ListFamily, String]
    _ = pipeline[F](List[Result[Int, String]]([Result[Int, String](Ok(1))])).attempt_tap(OnceObserver())
