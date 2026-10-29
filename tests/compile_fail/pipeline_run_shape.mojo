# error: no matching
from fp.functions import pipeline
from fp.effects import Reader, ReaderAction
@fieldwise_init
struct Bad(ReaderAction):
    comptime Family = Reader[Int]
    comptime Env = Int
    comptime Value = Int
    comptime Out[o: ImmOrigin] = String
    def run[o: ImmOrigin](deinit self, ref[o] env: Int) -> String: return "bad"
def main(): _ = pipeline(Bad()).run(0)
