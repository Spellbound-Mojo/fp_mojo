# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, State, WriterT, ReaderAction, StateAction, WriterValue, run, writer
from fp.algebra import ResultFamily, StringMonoid
from fp.data import Result, Ok
@fieldwise_init
struct Bad(ReaderAction):
    comptime Family = Reader[Int]
    comptime Env = String
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Int
    def run[o: ImmOrigin](deinit self, ref[o] env: String) -> Int: return 1

def inc(var x: Int) -> Int: return x + 1
def main(): _ = pipeline[Reader[Int]](Bad()).map(inc).get()
