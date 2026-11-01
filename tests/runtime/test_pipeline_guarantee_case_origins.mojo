"""Cleanup borrows end at execution while an independent success origin survives."""
from fp.functions import pipeline
from fp.effects import IO, ExitCase, Outcome, delay
from fp.algebra import pure
from fp.callables import OnceThunk
from std.testing import assert_equal


@fieldwise_init
struct CaseBorrowed[o: ImmOrigin](OnceThunk):
    var owner: Pointer[List[Int],Self.o]
    comptime Out = Span[Int,Self.o]
    def call_once(deinit self) -> Self.Out: return Span(self.owner[])


def external[o: ImmOrigin](ref[o] owner: List[Int]) raises -> Outcome[Span[Int,o],Error]:
    var calls = 0
    def cleanup(exit: ExitCase[Error]) {mut calls} -> IO[Error].Pure[Int]:
        calls += 1
        return pure[IO[Error]](1)
    var result = pipeline(delay[Error](CaseBorrowed(Pointer(to=owner)))).guarantee_case(cleanup).run_io()
    assert_equal(calls,1)
    return result^


def main() raises:
    var owner = List[Int]([7,11])
    var completed = external(owner)
    var result = completed.take()
    assert_equal(result.is_ok(),True)
    var view = result^._take_ok()
    assert_equal(Pointer(to=view[0]) == Pointer(to=owner[0]),True)
    assert_equal(view[1],11)
