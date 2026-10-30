# error: constraint
from fp.effects import Reader, ReaderAction, local

@fieldwise_init
struct UnionError(ReaderAction, Defaultable):
    comptime Family = Reader[List[Int]]
    comptime Env = List[Int]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Int
    # Form the native union as std.origin.Origin.contains does. This fixture
    # only checks the declared error type; it performs no origin cast.
    comptime Error[o: ImmOrigin] = Span[Int, origin_of(o._mlir_origin, ImmStaticOrigin._mlir_origin)]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Int:
        raise Self.Error[o]()

def same(env: List[Int]) -> List[Int]: return env.copy()
def main(): _ = local[Reader[List[Int]]](UnionError(), same)
