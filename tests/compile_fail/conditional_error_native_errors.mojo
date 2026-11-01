# The predicate raises Int and the handler raises String; no common native error exists.
# error: no matching method in call to 'recover_if'
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
def yes(error: String) raises Int -> Bool: return True
def wrong(var error: String) raises String -> Int: return 0
def main() raises:
    _ = pipeline[ResultFamily[String]](fail[ResultFamily[String], Int](String("bad"))).recover_if(yes, wrong).get()
