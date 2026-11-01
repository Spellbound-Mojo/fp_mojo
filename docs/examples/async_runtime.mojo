"""Run many programs on one work-stealing runtime; its last copy joins the workers."""
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Fiber, IORuntimeConfig, Profile, Runtime


def square(value: Int) -> Int:
    return value * value


@fieldwise_init
struct JoinBoth(OnceUnary):
    """Join a fiber that squares a number, and add its result to ours."""
    var mine: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(AddTo(self.mine))


@fieldwise_init
struct AddTo(OnceUnary):
    var mine: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        return self.mine + outcome.take()._take_ok()


def program(n: Int) -> IO[Int, Int]:
    # A fiber squares n on whichever worker takes it; the program adds n.
    return IO[Int, Int].pure(n).map(square).start().flat_map(JoinBoth(n))


def main() raises:
    var config = IORuntimeConfig()
    config.profile = Profile.work_stealing(2)
    var runtime = Runtime(config)
    print("profile:", config.profile)
    for n in range(1, 4):
        var outcome = runtime.run(program(n))
        print(n, "->", outcome.take()._take_ok())
    print("live fibers:", len(runtime.fibers()))
    # Dropping the last copy of the runtime stops and joins its two workers.
