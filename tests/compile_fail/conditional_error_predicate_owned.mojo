# A recover_if predicate borrows the stored error; an owned (var) predicate is rejected.
# error: no matching method in call to 'recover_if'
# error: cannot be converted from 'def wrong(var error: String)
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
def wrong(var error: String) -> Bool: return True
def restore(var error: String) -> Int: return 0
def main():
    _ = pipeline[ResultFamily[String]](fail[ResultFamily[String], Int](String("bad"))).recover_if(wrong, restore).get()
