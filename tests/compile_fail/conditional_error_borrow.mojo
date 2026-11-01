# error: uninitialized
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
def main():
    comptime R = ReaderT[ResultFamily[String], Int]
    var owner = String("capture")
    def predicate(error: String) {var owner^} -> Bool: return error == owner
    def restore(var error: String) -> Int: return 0
    var pending = pipeline[R](fail[R, Int](String("bad"))).recover_if(predicate, restore).get()
    var moved = predicate^
    _ = moved(String())
    _ = run[R](pending^, 0)
