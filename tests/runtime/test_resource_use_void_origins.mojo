"""Discarding a body result never erases borrowed cleanup errors."""
from fp.effects import resource, pure_resource, lift_resource, EffectFailure, Outcome
from fp.functions import pipeline
from fp.callables import OnceUnary
from fp.data import Result
from std.testing import assert_equal


@fieldwise_init
struct Release[o: ImmOrigin](OnceUnary):
    var error: Span[Int,Self.o]
    comptime Arg = Int
    comptime Out = NoneType
    comptime Error = Span[Int,Self.o]
    def call_once(deinit self, var value: Int) raises Self.Error -> NoneType:
        raise self.error


def acquired() -> Int: return 7


def borrowed(owner: List[Int]) raises:
    comptime E = Span[Int,origin_of(owner)]
    var native = resource[E](acquired,Release(Span(owner))).use_void()
    comptime assert type_of(native) == Result[NoneType,EffectFailure[E]]
    var failure = native^._take_err()
    assert_equal(failure.errors.first()[0],71)
    var scope = resource[E](acquired,Release(Span(owner)))
    var result = pipeline(lift_resource(scope^).use_void()).run_io()
    comptime assert type_of(result) == Outcome[NoneType,E]
    var stored = result.take()
    var failed = stored^._take_err()
    assert_equal(failed.errors.first()[0],71)


def main() raises:
    borrowed([71])
