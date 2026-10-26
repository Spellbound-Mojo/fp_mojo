# error: repeatable
from fp.functions import pipeline
from fp.data import Result, Ok
from fp.algebra import ResultFamily
from fp.callables import BorrowOnceCallable
from fp.algebra import ListFamily
from fp.effects import ResultT
@fieldwise_init
struct Once(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Bool
    def invoke_once(deinit self, ref value: Int) -> Bool: return True
def factory(value: Int) -> String: return String(value)
def main():
    comptime I = ResultT[ListFamily,String]
    _ = pipeline[I](List[Result[Int,String]]([Result[Int,String](Ok(1))])).ensure(Once(),factory)
