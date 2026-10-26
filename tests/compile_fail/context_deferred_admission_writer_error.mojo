# error: invalid call to 'writer': violated constraint
from fp.functions import pipeline
from fp.effects import Reader, State, WriterT, ReaderAction, StateAction, WriterValue, run, writer
from fp.algebra import ResultFamily, StringMonoid
from fp.data import Result, Ok
comptime W = WriterT[ResultFamily[Int], StringMonoid]
def main(): _ = writer[W, Int](Result[Tuple[String, Int], String](Ok(Tuple(String(), 1))))
