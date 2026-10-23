# error: repeatable
from fp.algebra import ResultFamily, ListFamily, OptionalFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import piped
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
@fieldwise_init
struct EOUncopyable(Movable):
    var value: Int
def inspect(error: EOUncopyable) -> List[Result[Int, EOUncopyable]]: return [Result[Int, EOUncopyable](Ok(0))]
def main():
    comptime F = ResultT[ListFamily, EOUncopyable]
    _ = piped(fail[F, Int](EOUncopyable(0))).flat_tap_err[F](inspect).get()
