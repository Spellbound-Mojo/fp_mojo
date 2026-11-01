"""Public resource metadata keeps independent value and error origins."""
from test_resource_scope_contracts import used
from fp.effects import IO, Outcome, ScopedIO
from fp.callables import OnceUnary
from fp.algebra import pure
from fp.functions import pipeline
from std.testing import assert_equal


@fieldwise_init
struct Release[o: ImmOrigin](OnceUnary):
    comptime Arg = Int
    comptime Out = IO[Span[Int,Self.o]].Pure[NoneType]
    def call_once(deinit self, var value: Int) -> Self.Out:
        var nothing: NoneType = None
        return pure[IO[Span[Int,Self.o]]](nothing)


@fieldwise_init
struct Project[v: ImmOrigin, e: ImmOrigin](ScopedIO):
    var value: Span[Int,Self.v]
    var error: Span[Int,Self.e]
    var fail: Bool
    comptime Input = Int
    comptime Value = Span[Int,Self.v]
    comptime Error = Span[Int,Self.e]
    comptime BuildError = Self.Error
    comptime Action[o: ImmOrigin] = IO[Self.Error].Pure[Self.Value]
    def build[o: ImmOrigin](deinit self, ref[o] input: Int) raises Self.Error -> Self.Action[o]:
        if self.fail: raise self.error
        return pure[IO[Self.Error]](self.value)


def borrowed(values: List[Int], errors: List[Int]) raises:
    comptime V = Span[Int,origin_of(values)]
    comptime E = Span[Int,origin_of(errors)]
    for fail in range(2):
        var acquire = pure[IO[E]](7)
        var pending = used(acquire^,Release[origin_of(errors)](),Project(Span(values),Span(errors),Bool(fail)))
        var outcome = pipeline(pending^).run_io()
        comptime assert type_of(outcome) == Outcome[V,E]
        var result = outcome.take()
        assert_equal(result.is_err(),Bool(fail))
        if fail:
            var failure = result^._take_err()
            assert_equal(failure.errors.first()[0],71)
        else:
            assert_equal(result._ok().value[0],11)


def main() raises:
    borrowed([11],[71])
