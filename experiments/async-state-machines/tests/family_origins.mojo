"""IO family selection and callbacks preserve external value and error origins."""
from fp.callables import OnceUnary
from fp.functions import pipeline
from fp.effects import IOContext
from fp.effects._async.engine import IO
from fp.effects._async.kernel import Machine, Step, run
from foundation import Borrowed, check


@fieldwise_init
struct Leaf[o: ImmOrigin](Machine):
    var source: Borrowed[Self.o]
    comptime Value = Span[Int, Self.o]
    comptime Error = Span[Int, Self.o]
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        return self.source.poll(context)


@fieldwise_init
struct Keep[o: ImmOrigin](OnceUnary):
    var fail: Bool
    comptime Arg = Span[Int, Self.o]
    comptime Out = Self.Arg
    comptime Error = Self.Arg
    def call_once(deinit self, var value: Self.Arg) raises Self.Error -> Self.Out:
        if self.fail:
            raise value
        return value


def exercise[o: ImmOrigin](ref[o] values: List[Int]):
    # The leaf's borrowed origin is the value's and error's, so the IO's type keeps it.
    var success = run(pipeline(IO[Span[Int, o], Span[Int, o]].lift(Leaf(Borrowed(Pointer(to=values), 0, False)))).map(Keep[o](False)).get())
    check(success.take()._take_ok()[0] == 13, "family mapping must preserve the value origin")
    var failed = run(pipeline(IO[Span[Int, o], Span[Int, o]].lift(Leaf(Borrowed(Pointer(to=values), 0, False)))).map(Keep[o](True)).get())
    var failure = failed.take()._take_err()
    check(failure.errors.first()[1] == 17, "family mapping must preserve the callback error origin")


def main():
    var values: List[Int] = [13, 17]
    exercise(values)
    print("family origins: lifted leaf in the IO family, borrowed values and exact borrowed errors")
