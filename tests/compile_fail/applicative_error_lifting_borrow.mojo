# error: uninitialized
from fp.algebra import ResultFamily, ListFamily, StringMonoid, ListMonoid, fail, pure
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ResultT, action, run
from fp.functions import piped
from fp.data import Result, Ok
comptime R = ReaderT[ResultFamily[String], Int]
def main():
    var owner = String("capture")
    def restore(var error: String) {var owner^} -> Int: return owner.byte_length()
    var pending = piped(fail[R, Int](String("bad"))).recover[R](restore).get()
    var moved = restore^
    _ = moved(String())
    _ = run[R](pending^, 0)
