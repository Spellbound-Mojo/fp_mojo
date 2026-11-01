# error: cannot be converted
from fp.algebra import ResultFamily, ListFamily, OptionalFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
def inspect(error: String) -> Int: return 0
def main(): _ = pipeline(Optional[Int]()).tap_err[OptionalFamily](inspect).get()
