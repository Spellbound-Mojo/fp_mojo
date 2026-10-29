"""Native async failure construction and selected Pipeline recovery stay deferred."""
from fp.algebra import pure
from fp.functions import pipeline
from fp.effects import EffectFailure
from fp.effects._async.family import Async
from fp.effects._async.kernel import run
from fp.effects._async.recovery import raise_error, handle_error_with
from foundation import check


def recover(var failure: EffectFailure[Int]) -> Async[Int].Pure[Int]:
    var errors = failure^.into_errors().into_list()
    return pure[Async[Int]](errors[0] + 1)


def main():
    var direct = run(handle_error_with(raise_error[Int, Int](41), recover))
    check(direct.take()._take_ok() == 42, "native handler receives deferred failure")
    var fluent = run(pipeline(raise_error[Int, Int](6)).or_else(recover).get())
    check(fluent.take()._take_ok() == 7, "Pipeline uses the shared recovery capability")
    print("native recovery: deferred raise_error, native handler, selected Pipeline or_else")
