# error: no matching method in call to 'tap_err'
# error: value passed to 'function' cannot be converted
from fp.algebra import ResultFamily, ListFamily, OptionalFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
def inspect(var error: String) -> Int: return 0
def main(): _ = pipeline[ResultFamily[String]](fail[ResultFamily[String], Int](String())).tap_err(inspect).get()
