# error: constraint
from fp.effects import Reader, ReaderAction, local
@fieldwise_init
struct BorrowError(ReaderAction, Defaultable):
    comptime Family = Reader[List[Int]]
    comptime Env = List[Int]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Int
    comptime Error[o: ImmOrigin] = Span[Int, o]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Int:
        raise Span(env)
def same(env: List[Int]) -> List[Int]: return env.copy()
def main(): _ = local[Reader[List[Int]]](same, BorrowError())
