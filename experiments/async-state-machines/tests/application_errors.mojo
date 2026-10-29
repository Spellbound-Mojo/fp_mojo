"""Native function signatures retain domain errors through the shared async owners."""
from fp.effects._async.application import pure, Pure, delay, callback, Completion, uncancelable_with, Poll
from fp.effects._async.kernel import run
from fp.callables import as_unary
from foundation import check


def fail() raises Int -> Int:
    raise 7


def register(var completion: Completion[Int, Int]) raises Int:
    raise 8


def withdraw() raises Int:
    raise 9


def masked(var poll: Poll[Int]) raises Int -> Pure[Int, Int]:
    raise 10


def main():
    var delayed = run(delay[Int](fail))
    var failure = delayed.take()._take_err()
    check(failure^.into_errors().into_list()[0] == 7, "native delayed domain failure")
    var thin: def() raises Int thin -> Int = fail
    var pointed = run(delay[Int](thin))
    var pointer_error = pointed.take()._take_err()
    check(pointer_error^.into_errors().into_list()[0] == 7, "native thin delayed failure")
    var registration: def(var Completion[Int, Int]) raises Int thin = register
    var cleanup: def() raises Int thin = withdraw
    var called = run(callback(as_unary(registration), delay[Int](cleanup)))
    var combined = called.take()._take_err()
    var errors = combined^.into_errors().into_list()
    check(len(errors) == 2 and errors[0] == 8 and errors[1] == 9, "registration and withdrawal errors retained in order")
    var mask_pointer: def(var Poll[Int]) raises Int thin -> Pure[Int, Int] = masked
    var mask = run(uncancelable_with[Int](as_unary(mask_pointer)))
    var mask_error = mask.take()._take_err()
    check(mask_error^.into_errors().into_list()[0] == 10, "native mask factory failure")
    print("application errors: exact native errors, thin callbacks, registration before withdrawal")
