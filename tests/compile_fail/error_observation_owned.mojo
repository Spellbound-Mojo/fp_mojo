# error: cannot be converted
from fp.algebra import ResultFamily, ListFamily, OptionalFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import piped
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
def inspect(var error: String) -> Int: return 0
def main(): _ = piped(fail[ResultFamily[String], Int](String())).tap_err[ResultFamily[String]](inspect).get()
