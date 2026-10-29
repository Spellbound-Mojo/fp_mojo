# error: no matching method
from fp.effects._async.resources import resource
from fp.effects._async.composition import pure, Pure
from fp.effects._async.scopes import ScopedMachine
from fp.effects import IOContext
from fp.effects._async.kernel import Step
@fieldwise_init
struct Release(ScopedMachine):
    comptime Input = List[Int]
    comptime Value = NoneType
    comptime Error = Int
    def poll[o: ImmOrigin](mut self, ref[o] value: Self.Input, context: IOContext[Int]) -> Step[NoneType, Int]:
        var unit: NoneType = None
        var done = pure[Int](unit)
        return done.poll(context)
def escape[o: ImmOrigin](ref[o] values: List[Int]) -> Span[Int, o]:
    return Span(values)
def main():
    var values: List[Int] = [1]
    _ = resource(pure[Int](values^), Release()).map(escape)
