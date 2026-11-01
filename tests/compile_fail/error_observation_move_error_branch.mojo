# error: no matching method in call to 'flat_tap_err'
from fp.algebra import ResultFamily, ListFamily, OptionalFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
@fieldwise_init
struct EOUncopyable(Movable):
    var value: Int
def inspect(error: EOUncopyable) -> List[Result[Int, EOUncopyable]]: return [Result[Int, EOUncopyable](Ok(0))]
def main():
    comptime F = ResultT[ListFamily, EOUncopyable]
    _ = pipeline[F](fail[F, Int](EOUncopyable(0))).flat_tap_err(inspect).get()
