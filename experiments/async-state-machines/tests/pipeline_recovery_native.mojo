"""Native async failure construction and selected Pipeline recovery stay deferred."""
from fp.functions import pipeline
from fp.effects import EffectFailure
from fp.effects._async.engine import IO
from fp.effects._async.kernel import run
from foundation import check


def recover(var failure: EffectFailure[Int]) -> IO[Int, Int]:
    var errors = failure^.into_errors().into_list()
    return IO[Int, Int].pure(errors[0] + 1)


def main():
    var direct = run(IO[Int, Int].raise_error(41).handle_error_with(recover))
    check(direct.take()._take_ok() == 42, "native handler receives deferred failure")
    var fluent = run(pipeline(IO[Int, Int].raise_error(6)).handle_error_with(recover).get())
    check(fluent.take()._take_ok() == 7, "Pipeline uses the shared recovery capability")
    print("native recovery: deferred raise_error, native handler, selected Pipeline handle_error_with")
