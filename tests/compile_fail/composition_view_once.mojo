# error: cannot be implicitly copied
from fp.functions import pipeline, flow
from fp.callables import OnceUnary

@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    var offset: Int
    def call_once(deinit self, var value: Int) -> Int: return value + self.offset

def main():
    var chain = flow(Once(1), Once(2))
    _ = pipeline(1).then(chain).get()
