"""Select effectful cleanup from success, failure, or cancellation."""
from fp.effects import IO, ExitCase, DelayContract, Poll, delay, canceled, uncancelable_with
from fp.functions import pipeline
from fp.callables import OnceThunk, OnceUnary
from fp.algebra import pure


@fieldwise_init
struct ReportExit(OnceThunk):
    var message: String
    comptime Out = NoneType
    def call_once(deinit self) -> NoneType:
        print(self.message)
        return None


def report_exit(exit: ExitCase[Int]) -> DelayContract[ReportExit, Int].Out:
    var message = String("released after success")
    if exit.is_canceled():
        message = "released after cancellation"
    elif exit.is_error():
        message = "released after error"
    return delay[Int](ReportExit(message^))


@fieldwise_init
struct CancelableRegion(OnceUnary):
    comptime Arg = Poll[Int]
    comptime Out = Poll[Int].Applied[type_of(canceled[Int]())]
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        return poll.apply(canceled[Int]())


def main():
    var success = pipeline(pure[IO[Int]](42)).guarantee_case(report_exit).run_io()
    var result = success.take()
    print("result:", result^._take_ok())
    var body = uncancelable_with[Int](CancelableRegion())
    var canceled_result = pipeline(body^).guarantee_case(report_exit).run_io()
    print("canceled:", not canceled_result)
