# error: cannot be converted
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import piped
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
def wrong(var error: String) -> Bool: return True
def restore(var error: String) -> Int: return 0
def main():
    _ = piped(fail[ResultFamily[String], Int](String("bad"))).recover_if[ResultFamily[String]](wrong, restore).get()
