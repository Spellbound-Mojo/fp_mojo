# error: repeatable
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.callables import BorrowOnceCallable
from fp.functions import piped
from fp.data import Result, Ok
@fieldwise_init
struct OncePredicate(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Bool
    def invoke_once(deinit self, ref value: Int) raises Never capturing -> Bool: return True
def factory(value: Int) -> String: return "bad"
def main():
    comptime F = ResultT[ListFamily, String]
    _ = piped(List[Result[Int, String]]([Result[Int, String](Ok(1))])).ensure[F](OncePredicate(), factory)
