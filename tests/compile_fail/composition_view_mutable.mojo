# error: cannot be implicitly copied
from fp.functions import pipeline, flow
from fp.callables import MutableUnary

@fieldwise_init
struct Counter(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    var total: Int
    def call_mut(mut self, var value: Int) -> Int:
        self.total += value
        return self.total

def main():
    var chain = flow(Counter(0), Counter(0))
    _ = pipeline(1).then(chain).get()
