# error: uninitialized
from fp.algebra import ResultFamily, ListFamily, OptionalFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
def main():
    comptime F = ReaderT[ResultFamily[String], Int]
    var capture = String("retained")
    def inspect(error: String) {var capture^} -> Int: return capture.byte_length()
    var pending = pipeline[F](fail[F, Int](String())).tap_err(inspect).get()
    var moved = inspect^
    _ = moved(String())
    _ = run[F](pending^, 0)
