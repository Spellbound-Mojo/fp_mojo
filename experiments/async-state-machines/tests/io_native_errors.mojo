"""Native function signatures keep their domain errors through IO's owners."""
from fp.effects._async.engine import IO
from fp.effects._async.callbacks import Completion
from fp.effects._async.finalization import Poll
from fp.effects._async.kernel import run
from fp.callables import as_unary
from foundation import check


def fail() raises Int -> Int:
    raise 7


def register(var completion: Completion[Int, Int]) raises Int:
    raise 8


def withdraw() raises Int -> NoneType:
    raise 9


def masked(var poll: Poll[Int]) raises Int -> IO[Int, Int]:
    raise 10


def main():
    var delayed = run(IO[Int, Int].delay(fail))
    var failure = delayed.take()._take_err()
    check(failure^.into_errors().into_list()[0] == 7, "native delayed domain failure")
    var thin: def() raises Int thin -> Int = fail
    var pointed = run(IO[Int, Int].delay(thin))
    var pointer_error = pointed.take()._take_err()
    check(pointer_error^.into_errors().into_list()[0] == 7, "stored thin pointer delayed failure")
    var registration: def(var Completion[Int, Int]) raises Int thin = register
    var cleanup: def() raises Int thin -> NoneType = withdraw
    var called = run(IO[Int, Int].async(as_unary(registration), IO[NoneType, Int].delay(cleanup)))
    var combined = called.take()._take_err()
    var errors = combined^.into_errors().into_list()
    check(len(errors) == 2 and errors[0] == 8 and errors[1] == 9, "registration and withdrawal errors retained in order")
    var mask_pointer: def(var Poll[Int]) raises Int thin -> IO[Int, Int] = masked
    var mask = run(IO[Int, Int].uncancelable(as_unary(mask_pointer)))
    var mask_error = mask.take()._take_err()
    check(mask_error^.into_errors().into_list()[0] == 10, "native mask factory failure")
    print("io native errors: exact native errors, stored thin pointers, registration before withdrawal")
