"""Stored resource callbacks preserve independent external value/error borrows."""
from fp.effects import IO, Outcome, lift_resource, pure_resource, run_io
from std.testing import assert_equal


@fieldwise_init
struct Views[v: ImmOrigin, e: ImmOrigin](Copyable, Movable):
    var value: Span[Int,Self.v]
    var error: Span[Int,Self.e]
    var fail: Bool


def build[v: ImmOrigin, e: ImmOrigin](views: Views[v,e]) raises Span[Int,e] -> IO[Span[Int,e]].Pure[Span[Int,v]]:
    if views.fail: raise views.error
    return IO[Span[Int,e]].pure(views.value)


def borrow_views(values: List[Int], errors: List[Int]) raises:
    comptime V = Span[Int,origin_of(values)]
    comptime E = Span[Int,origin_of(errors)]
    comptime T = Views[origin_of(values),origin_of(errors)]
    var pointer: def(T) raises E thin -> IO[E].Pure[V] = build[origin_of(values),origin_of(errors)]
    for operation in range(3):
        for fail in range(2):
            var resource = lift_resource(pure_resource[E](T(Span(values),Span(errors),Bool(fail))))
            var outcome: Outcome[V,E]
            if operation == 0:
                outcome = run_io(resource^.use(pointer))
            elif operation == 1:
                outcome = run_io(resource^.eval_map(pointer).surround(IO[E].pure(Span(values))))
            else:
                outcome = run_io(resource^.eval_tap(pointer).surround(IO[E].pure(Span(values))))
            var result = outcome.take()
            assert_equal(result.is_err(),Bool(fail))
            if fail:
                var failure = result^._take_err()
                assert_equal(failure.errors.first()[0],71)
            else:
                assert_equal(result._ok().value[0],11)


def main() raises:
    borrow_views([11],[71])
