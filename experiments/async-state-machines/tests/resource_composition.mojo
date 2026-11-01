"""Native borrowing callbacks compose Resource through nested resumable scope owners."""
from std.memory import ArcPointer
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok
from fp.effects import IOContext, EffectFailure, ExitCase
from fp.effects._async.kernel import Step, Wait, run
from fp.effects._async.scopes import CleanupMachine
from fp.effects._async.engine import IO
from fp.effects._async.io_resource import Resource
from foundation import check


@fieldwise_init
struct Release(CleanupMachine):
    comptime Input = Int
    comptime Error = Int
    var log: ArcPointer[List[Int]]
    var phase: Int
    def poll[o: ImmOrigin](mut self, ref[o] value: Int, exit: ExitCase[Int], context: IOContext[Int]) -> Step[NoneType, Int]:
        if self.phase == 0:
            self.phase = 1
            return .pending(Wait())
        self.log[].append(value)
        var unit: NoneType = None
        return .ready(Optional(Result[NoneType, EffectFailure[Int]](Ok(unit))))


@fieldwise_init
struct Next(BorrowOnceCallable):
    var log: ArcPointer[List[Int]]
    comptime Payload = Int
    comptime Result = Resource[Int, Int]
    def invoke_once(deinit self, ref value: Int) -> Self.Result:
        return Resource[Int, Int].make_case(IO[Int, Int].pure(value + 1), Release(self.log^, 0))


def double(value: Int) -> Int:
    return value * 2


def body(value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value + 3)


def main():
    var log = ArcPointer(List[Int]())
    var program = Resource[Int, Int].make_case(IO[Int, Int].pure(10), Release(log.copy(), 0)).map(double).flat_map(Next(log.copy())).use(body)
    var result = run(program^)
    check(result.take()._take_ok() == 24, "native resource callbacks compose in order")
    check(len(log[]) == 2 and log[][0] == 21 and log[][1] == 10, "all releases finish once, inner before outer")
    print("resource composition: native map/flat_map/use, reverse suspended release")
