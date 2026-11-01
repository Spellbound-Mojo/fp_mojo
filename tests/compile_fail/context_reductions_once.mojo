# error: no matching method
from fp.functions import pipeline
from fp.callables import OnceUnary
@fieldwise_init
struct Step(OnceUnary):
    comptime Arg=Int
    comptime Out=Int
    def call_once(deinit self,var value:Int) -> Int: return value
def main(): _ = pipeline(range(3)).sum_by(Step()).get()
