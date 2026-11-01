# error: no matching
from fp.functions import pipeline
from fp.algebra import StringMonoid
from fp.callables import UnaryContract
@fieldwise_init
struct NoReceiver(UnaryContract):
    comptime Arg = Int
    comptime Out = Optional[String]
def main() raises:
    _ = pipeline(List[Int]([1])).fold_map_effect[StringMonoid](NoReceiver())
