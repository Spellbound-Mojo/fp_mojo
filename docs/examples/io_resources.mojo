"""Compose effectful scopes and observe the outcome during release."""
from fp.effects import ExitCase, ScopedIO, DelayContract, resource_io, resource_io_case, delay, run_io, canceled
from fp.callables import OnceThunk


def open_session() -> String:
    print("open session")
    return "session"


@fieldwise_init
struct CloseSession(OnceThunk):
    var name: String
    var reason: String
    comptime Out = NoneType
    def call_once(deinit self) -> NoneType:
        print("close", self.name, self.reason)
        return None


def close_session(var name: String) -> DelayContract[CloseSession, Int].Out:
    return delay[Int](CloseSession(name^, "after use"))


@fieldwise_init
struct CloseWithCase(ScopedIO):
    var name: String
    comptime Input = ExitCase[Int]
    comptime Value = NoneType
    comptime Error = Int
    comptime Action[o: ImmOrigin] = DelayContract[CloseSession, Int].Out
    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) -> Self.Action[o]:
        var reason = String("after success")
        if value.is_canceled():
            reason = "after cancellation"
        elif value.is_error():
            reason = "after error"
        return delay[Int](CloseSession(self.name^, reason^))


def close_with_case(var name: String) -> CloseWithCase:
    return CloseWithCase(name^)


def main():
    var scope = resource_io(delay[Int](open_session), close_session)
    # Acquisition and cleanup remain deferred until this IO program is run.
    var result = run_io(scope^.use_void())
    var success = result.take()
    print("completed:", success.is_ok())
    var observed = resource_io_case(delay[Int](open_session), close_with_case)
    var outcome = run_io(observed^.surround(canceled[Int]()))
    print("canceled:", not outcome)
