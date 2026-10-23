# error: constraint
from fp.algebra import ResultFamily, ListFamily, StringMonoid, ListMonoid, fail, pure
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ResultT, action, run
from fp.functions import piped
from fp.data import Result, Ok
@fieldwise_init
struct AELMove(Movable):
    var value: Int
def main():
    _ = fail[StateT[ResultFamily[String], AELMove], Int](String("bad"))
