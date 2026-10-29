from fp.effects._async.application import pure, Pure, delay, both, callback, Completion, guarantee, uncancelable_with, Poll
from fp.effects._async.kernel import run
from fp.functions import pipeline
from fp.effects import EffectFailure
from fp.data import Result, Ok
from std.os import abort


def add(var value: Int) -> Int:
    return value + 1


def register(var complete: Completion[Int, Int]):
    _ = complete.complete(Optional(Result[Int, EffectFailure[Int]](Ok(41))))


def masked(var poll: Poll[Int]) -> Poll[Int].Applied[Pure[Int, Int]]:
    return poll.apply(pure[Int](41))


def main():
    var deferred = callback(register, pure[Int](NoneType()))
    var result = run(pipeline(guarantee(deferred^, pure[Int](NoneType()))).map(add).get())
    if result.take()._take_ok() != 42:
        abort("native callback result")
    var protected = run(pipeline(uncancelable_with[Int](masked)).map(add).get())
    if protected.take()._take_ok() != 42:
        abort("native mask and family-aware poll result")
    print("application: native callback and mask factories, logical aliases, Pipeline composition")
