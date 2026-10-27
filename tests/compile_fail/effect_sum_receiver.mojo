# error: no matching
from fp.functions import pipeline
from fp.callables import UnaryContract
@fieldwise_init
struct NoReceiver(UnaryContract):
    comptime Arg = Int
    comptime Out = Optional[Int]
def main() raises:
    _ = pipeline(List[Int]([1])).sum_by_effect(NoReceiver())
