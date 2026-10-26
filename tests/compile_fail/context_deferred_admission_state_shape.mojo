# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, State, WriterT, ReaderAction, StateAction, WriterValue, run, writer
from fp.algebra import ResultFamily, StringMonoid
from fp.data import Result, Ok
@fieldwise_init
struct Bad(StateAction):
    comptime Family = State[Int]
    comptime State = Int
    comptime Value = Int
    comptime Out = Int
    def run(deinit self, var state: Int) -> Int: return state

def inc(var x: Int) -> Int: return x + 1
def main(): _ = pipeline[State[Int]](Bad()).map(inc).get()
