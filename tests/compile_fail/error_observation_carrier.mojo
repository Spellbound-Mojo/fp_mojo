# error: no matching method
from fp.algebra import ResultFamily, ListFamily, OptionalFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import piped
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
def inspect(error: String) -> Result[Int, Int]: return Ok(0)
def main(): _ = piped(fail[ResultFamily[String], Int](String())).flat_tap_err[ResultFamily[String]](inspect).get()
