# error: use of uninitialized value 'observer'
from fp.functions import partial, piped
from fp.data import err
from fp.algebra import ResultFamily
from fp.effects import ReaderT, run

def above(limit: Int, value: Int) -> Bool: return value > limit
def main():
    comptime I = ReaderT[ResultFamily[Int], Int]
    var observer = partial(above, 2)
    var pending = piped(I.lift(err[String](3))).tap_err[I](observer).get()
    var moved = observer^
    _ = moved(4)
    _ = run[I](pending^, 0)
