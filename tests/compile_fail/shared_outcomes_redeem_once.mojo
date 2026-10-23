# error: repeatable
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.callables import OnceUnary
from fp.functions import piped
from fp.data import Result, Ok
@fieldwise_init
struct OnceHandler(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int: return value
def error(var value: String) -> Int: return 0
def main():
    comptime F = ResultT[ListFamily, String]
    _ = piped(List[Result[Int, String]]([Result[Int, String](Ok(1))])).redeem[F](OnceHandler(), error)
