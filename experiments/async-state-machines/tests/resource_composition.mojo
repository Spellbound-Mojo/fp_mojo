"""Native borrowing callbacks compose through nested resumable scope owners."""
from std.memory import ArcPointer
from fp.data import Result, Ok
from fp.effects import IOContext, EffectFailure
from fp.effects._async.kernel import Step, Wait, run
from fp.effects._async.scopes import ScopedMachine
from fp.effects._async.composition import Pure, pure
from fp.effects._async.resources import resource, Resource
from foundation import check


@fieldwise_init
struct Release(ScopedMachine):
    comptime Input = Int
    comptime Value = NoneType
    comptime Error = Int
    var log: ArcPointer[List[Int]]
    var phase: Int
    def poll[o: ImmOrigin](mut self, ref[o] value: Int, context: IOContext[Int]) -> Step[NoneType, Int]:
        if self.phase == 0:
            self.phase = 1
            return .pending(Wait())
        self.log[].append(value)
        var unit: NoneType = None
        return .ready(Optional(Result[NoneType, EffectFailure[Int]](Ok(unit))))


comptime Recipe = Resource[Pure[Int, Int], Release]


def double(value: Int) -> Int:
    return value * 2


def body(value: Int) -> Pure[Int, Int]:
    return pure[Int](value + 3)


def main():
    var log = ArcPointer(List[Int]())
    def next(value: Int) {log} -> Recipe:
        return resource(pure[Int](value + 1), Release(log.copy(), 0))
    var program = resource(pure[Int](10), Release(log.copy(), 0)).map(double).flat_map(next).use(body)
    var result = run(program^)
    check(result.take()._take_ok() == 24, "native resource callbacks compose in order")
    check(len(log[]) == 2 and log[][0] == 21 and log[][1] == 10, "all releases finish once, inner before outer")
    print("resource composition: native map/flat_map/use, reverse suspended release")
