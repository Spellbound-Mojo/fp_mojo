# error: cannot implicitly convert
from fp.effects import resource, EffectFailure
from fp.callables import OnceUnary
from fp.data import Result
@fieldwise_init
struct Release[o: ImmOrigin](OnceUnary):
    var error: Span[Int,Self.o]
    comptime Arg = Int
    comptime Out = NoneType
    comptime Error = Span[Int,Self.o]
    def call_once(deinit self, var value: Int) raises Self.Error -> NoneType: raise self.error
def acquired() -> Int: return 7
def run(ref owner: List[Int]) -> Result[NoneType,EffectFailure[Span[Int,origin_of(owner)]]]:
    return resource[Span[Int,origin_of(owner)]](acquired,Release(Span(owner))).use_void()
def escape() -> Result[NoneType,EffectFailure[Span[Int,ImmUntrackedOrigin]]]:
    var owner = List[Int]([71])
    return run(owner)
def main(): _ = escape()
