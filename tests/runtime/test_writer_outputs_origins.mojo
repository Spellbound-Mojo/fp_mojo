"""Writer selections retain independent payload, log and deferred-error origins."""
from fp.effects import Writer, WriterT, Reader, writer, run_value, run_log, asks
from fp.algebra import ListMonoid
from fp.functions import pipeline
from std.testing import assert_equal


def check(values: List[Int],logs: List[Int],errors: List[Int]) raises:
    comptime V = Span[Int,origin_of(values)]
    comptime L = Span[Int,origin_of(logs)]
    comptime E = Span[Int,origin_of(errors)]
    comptime W = Writer[ListMonoid[L]]
    var selected = run_value[W](writer[W,V]((List[L]([Span(logs)]),Span(values))))
    comptime assert type_of(selected) == V
    assert_equal(selected[0],11)
    var written = pipeline(writer[W,V]((List[L]([Span(logs)]),Span(values)))).run_log()
    comptime assert type_of(written) == List[L]
    assert_equal(written[0][0],23)

    comptime D = WriterT[Reader[Int],ListMonoid[L]]
    var deferred = pipeline(writer[D,V](Reader[Int].pure((List[L]([Span(logs)]),Span(values))))).run_value()
    comptime assert type_of(deferred).Value == V
    assert_equal(pipeline(deferred^).run(0)[0],11)
    var deferred_log = run_log[D](writer[D,V](Reader[Int].pure((List[L]([Span(logs)]),Span(values)))))
    comptime assert type_of(deferred_log).Value == List[L]
    assert_equal(pipeline(deferred_log^).run(0)[0][0],23)

    var error_view = Span(errors)
    def fail(env: Int) raises E {error_view} -> Tuple[List[L],V]: raise error_view
    for log_only in range(2):
        var observed: Optional[E] = None
        if log_only:
            var pending = pipeline(writer[D,V](asks[Reader[Int]](fail))).raising[String]().run_log()
            try: _ = pipeline(pending^).run(0)
            except error:
                comptime assert type_of(error) == E
                observed = Optional(error)
        else:
            var pending = pipeline(writer[D,V](asks[Reader[Int]](fail))).raising[String]().run_value()
            try: _ = pipeline(pending^).run(0)
            except error:
                comptime assert type_of(error) == E
                observed = Optional(error)
        assert_equal(observed.take()[0],71)


def main() raises:
    check([11],[23],[71])
