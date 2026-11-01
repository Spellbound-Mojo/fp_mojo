# error: no matching function in call to 'run'
# error: RunCompatible
from fp.functions import pipeline
from fp.effects import Reader, State, WriterT, ReaderAction, StateAction, WriterValue, run, writer
from fp.algebra import ResultFamily, StringMonoid
from fp.data import Result, Ok
@fieldwise_init
struct Bad(ReaderAction):
    comptime Family = Reader[Int]
    comptime Env = Int
    comptime Value = Int
    comptime Out[o: ImmOrigin] = String
    def run[o: ImmOrigin](deinit self, ref[o] env: Int) -> String: return "bad"

def main(): _ = run[Reader[Int]](Bad(), 0)
