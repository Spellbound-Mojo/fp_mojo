# error: does not conform
from fp.functions import pipeline
from fp.effects import Reader, ResultT, run
comptime R = Reader[Int]
def twice(var value: Int) -> Int: return value * 2

from fp.effects import ReaderAction
@fieldwise_init
struct Invalid(ReaderAction):
    comptime Family = Int
    comptime Env = Int
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Int
    def run[o: ImmOrigin](deinit self, ref[o] env: Int) -> Int: return env
def main():
    _ = pipeline(Invalid())
