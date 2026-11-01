# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily, StringMonoid
from fp.callables import OnceUnary

@fieldwise_init
struct Consume(OnceUnary):
    var value: Int
    comptime Arg = Int
    comptime Out = Optional[String]
    def call_once(deinit self, var arg: Int) -> Self.Out: return Optional(String(arg + self.value))

def main():
    var chain = kleisli[OptionalFamily](Consume(1))
    _ = pipeline(List[Int]([1, 2])).fold_map_effect[StringMonoid](chain).get()
