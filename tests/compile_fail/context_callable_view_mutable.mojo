# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily
from fp.callables import MutableUnary

@fieldwise_init
struct Counter(MutableUnary):
    var count: Int
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call_mut(mut self, var arg: Int) -> Self.Out:
        self.count += 1
        return Optional(arg + self.count)

def main():
    var chain = kleisli[OptionalFamily](Counter(0))
    _ = pipeline(List[Int]([1, 2])).map(chain).get()
