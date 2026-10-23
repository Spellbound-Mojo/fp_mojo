# error: incompatible native errors
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import piped
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
def yes(error: String) raises Int -> Bool: return True
def wrong(var error: String) raises String -> Int: return 0
def main() raises:
    _ = piped(fail[ResultFamily[String], Int](String("bad"))).recover_if[ResultFamily[String]](yes, wrong).get()
