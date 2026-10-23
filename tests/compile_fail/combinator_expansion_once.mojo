# error: traverse: the callback must be repeatable
from fp.functions import piped
from fp.callables import OnceUnary
@fieldwise_init
struct ExpansionOnce(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var arg: Int) -> Int: return arg
def main():
    _ = piped(List[Int]([1, 2])).sum_by(ExpansionOnce()).get()
