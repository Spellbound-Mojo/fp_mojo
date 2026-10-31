# sum_by requires RepeatableUnary; a once callback is rejected.
# error: no matching method in call to 'sum_by'
# error: violated constraint
from fp.functions import pipeline
from fp.callables import OnceUnary
@fieldwise_init
struct ExpansionOnce(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var arg: Int) -> Int: return arg
def main():
    _ = pipeline(List[Int]([1, 2])).sum_by(ExpansionOnce()).get()
