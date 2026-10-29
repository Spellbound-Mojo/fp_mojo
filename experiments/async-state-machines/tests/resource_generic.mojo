from fp.effects._async.resources import ResourcePlan, AsyncResource, ResourceCase, resource_case
from fp.effects._async.scopes import ScopedMachine, CleanupMachine
from fp.effects._async.application import pure, Pure
from fp.effects._async.kernel import run, Step
from fp.effects import IOContext, ExitCase
from fp.callables import BorrowOnceCallable, BorrowCallContract, BorrowSignature
from fp.data import Result, Ok
from fp.effects import EffectFailure
from std.os import abort


def use_recipe[P: ResourcePlan, U: ScopedMachine](var resource: AsyncResource[P], var body: U) -> AsyncResource[P].Used[U] where P.Value == U.Input and P.Error == U.Error:
    return resource^.use(body^)


def project[P: ResourcePlan, F: BorrowCallContract & Movable & Deinitable](var resource: AsyncResource[P], var function: F) -> AsyncResource[P].Mapped[F] where AsyncResource[P].MapCompatible[F]:
    return resource^.map(function^)


def compose[P: ResourcePlan, F: BorrowCallContract & Movable & Deinitable](var resource: AsyncResource[P], var function: F) -> AsyncResource[P].Bound[F] where AsyncResource[P].BindCompatible[F]:
    return resource^.flat_map(function^)


def use_factory[P: ResourcePlan, F: BorrowCallContract & Movable & Deinitable](var resource: AsyncResource[P], var function: F) -> AsyncResource[P].Use[F] where AsyncResource[P].UseCompatible[F]:
    return resource^.use(function^)


def body(value: Int) -> Pure[Int, Int]:
    return pure[Int](value + 2)


@fieldwise_init
struct Double(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Int
    def invoke_once(deinit self, ref value: Int) -> Int:
        return value * 2


@fieldwise_init
struct Body(ScopedMachine):
    comptime Input = Int
    comptime Value = Int
    comptime Error = Int
    def poll[o: ImmOrigin](mut self, ref[o] value: Int, context: IOContext[Int]) -> Step[Int, Int]:
        return .ready(Optional(Result[Int, EffectFailure[Int]](Ok(value + 2))))


@fieldwise_init
struct Release(CleanupMachine):
    comptime Input = Int
    comptime Error = Int
    def poll[o: ImmOrigin](mut self, ref[o] value: Int, exit: ExitCase[Int], context: IOContext[Int]) -> Step[NoneType, Int]:
        return .ready(Optional(Result[NoneType, EffectFailure[Int]](Ok(NoneType()))))


@fieldwise_init
struct Next(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = ResourceCase[Pure[Int, Int], Release]
    def invoke_once(deinit self, ref value: Int) -> Self.Result:
        return resource_case(pure[Int](value + 1), Release())


def main():
    var resource = resource_case(pure[Int](19), Release())
    var composed = compose(resource^, Next())
    var outcome = run(use_recipe(project(composed^, Double()), Body()))
    if outcome.take()._take_ok() != 42:
        abort("generic resource ownership")
    var pointer: def(Int) thin -> Pure[Int, Int] = body
    var native = BorrowSignature[Int, Pure[Int, Int]].capture(pointer)
    var second = resource_case(pure[Int](40), Release())
    var result = run(use_factory(second^, native^))
    if result.take()._take_ok() != 42:
        abort("generic borrowed body factory")
    print("resource generic: logical aliases, borrowed projection, dependent composition, scoped use, native body factory")
