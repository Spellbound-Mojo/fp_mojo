# error: cannot be converted
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import piped
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
def yes(error: String) -> Bool: return True
def restore(var error: String) -> Int: return 0
def main():
    _ = piped(Optional[Int]()).recover_if[OptionalFamily](yes, restore).get()
