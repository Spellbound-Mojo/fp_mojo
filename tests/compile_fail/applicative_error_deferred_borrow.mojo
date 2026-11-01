# error: uninitialized
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.effects import Reader, ResultT, run
def main():
    var owner = String("capture")
    def restore(var error: String) {var owner^} -> Int: return owner.byte_length()
    comptime F = ResultT[Reader[Int], String]
    var pending = pipeline[F](fail[F, Int](String("bad"))).recover(restore).get()
    var moved = restore^
    _ = moved(String())
    _ = run[Reader[Int]](pending^, 0)
