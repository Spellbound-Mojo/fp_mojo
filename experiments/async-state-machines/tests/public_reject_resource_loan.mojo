from fp.data import Result, Ok
from fp.effects import EffectFailure, IOContext
# error: no matching method
from fp.effects.async_runtime import resource, pure, Pure
from fp.effects.async_runtime.protocols import ScopedMachine, Step
@fieldwise_init
struct Release(ScopedMachine):
    comptime Input = List[Int]
    comptime Value = NoneType
    comptime Error = Int
    def poll[o: ImmOrigin](mut self, ref[o] value: Self.Input, context: IOContext[Int]) -> Step[NoneType, Int]:
        var unit: NoneType = None
        return .ready(Optional(Result[NoneType, EffectFailure[Int]](Ok(unit))))
def escape[o: ImmOrigin](ref[o] values: List[Int]) -> Span[Int, o]:
    return Span(values)
def main():
    var values: List[Int] = [1]
    _ = resource(pure[Int](values^), Release()).map(escape)
