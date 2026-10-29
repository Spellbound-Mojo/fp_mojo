"""Projection and scoped factories keep independent external value/error origins."""
from fp.effects import Reader, State, IO, Outcome, asks, inspect, run, scoped_io, lift_resource, pure_resource, run_io
from std.testing import assert_equal


@fieldwise_init
struct BorrowFactoryViews[v: ImmOrigin, e: ImmOrigin](Copyable, Movable):
    var value: Span[Int,Self.v]
    var error: Span[Int,Self.e]
    var fail: Bool


def project[v: ImmOrigin,e: ImmOrigin](view: BorrowFactoryViews[v,e]) raises Span[Int,e] -> Span[Int,v]:
    if view.fail: raise view.error
    return view.value


def effect[v: ImmOrigin,e: ImmOrigin](view: BorrowFactoryViews[v,e]) raises Span[Int,e] -> IO[Span[Int,e]].Pure[Span[Int,v]]:
    return IO[Span[Int,e]].pure(project(view))


def borrowed(values: List[Int], errors: List[Int]) raises:
    comptime V = Span[Int,origin_of(values)]
    comptime E = Span[Int,origin_of(errors)]
    comptime T = BorrowFactoryViews[origin_of(values),origin_of(errors)]
    var pointer: def(T) raises E thin -> V = project[origin_of(values),origin_of(errors)]
    var io_pointer: def(T) raises E thin -> IO[E].Pure[V] = effect[origin_of(values),origin_of(errors)]
    for fail in range(2):
        var view = T(Span(values),Span(errors),Bool(fail))
        var reader = asks[Reader[T]](pointer)
        comptime assert type_of(reader).Value == V
        comptime assert type_of(reader).Error[origin_of(view)] == E
        var read_value: Optional[V] = None
        try: read_value = Optional(run[Reader[T]](reader^,view))
        except error: assert_equal(error[0],71)
        assert_equal(Bool(read_value),not Bool(fail))
        if read_value: assert_equal(read_value.take()[0],11)

        var state = inspect[State[T]](pointer)
        comptime assert type_of(state).Value == V and type_of(state).Error == E
        var state_value: Optional[Tuple[V,T]] = None
        try: state_value = Optional(run[State[T]](state^,view.copy()))
        except error: assert_equal(error[0],71)
        assert_equal(Bool(state_value),not Bool(fail))
        if state_value:
            var result = state_value.take()
            assert_equal(result[0][0],11)
            assert_equal(result[1].error[0],71)

        var scoped = scoped_io(io_pointer)
        comptime assert type_of(scoped).Value == V and type_of(scoped).Error == E
        var outcome = run_io(lift_resource(pure_resource[E](view^)).use(scoped^))
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
