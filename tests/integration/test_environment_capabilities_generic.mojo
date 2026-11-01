"""Third-party Ask dictionaries and exact native construction errors."""
from fp.algebra import IdentityFamily, Monoid
from fp.effects import Ask, LiftAsk, ReaderT, WriterT, ask, run
from std.testing import assert_equal


@fieldwise_init
struct ECReadFailure(Movable):
    var code: Int


struct ECFixedEnvironment[fail_read: Bool](Ask):
    comptime Family = IdentityFamily
    comptime Environment = Int
    comptime AskAvailable = True
    comptime Asked = Int
    comptime AskError = ECReadFailure
    @staticmethod
    def ask() raises ECReadFailure -> Int:
        if Self.fail_read: raise ECReadFailure(11)
        return 8


struct ECFailingLog(Monoid):
    comptime Value = String
    comptime Error = ECReadFailure
    @staticmethod
    def empty() raises ECReadFailure -> String: raise ECReadFailure(22)
    @staticmethod
    def combine(var left: String, var right: String) raises ECReadFailure -> String:
        return left + right


def ec_read[C: Ask]() raises C.AskError -> C.Asked where C.AskAvailable:
    return ask[C]()


def main() raises:
    comptime W = WriterT[IdentityFamily, ECFailingLog]
    var code = 0
    try:
        _ = ec_read[LiftAsk[W, ECFixedEnvironment[True]]]()
    except error:
        comptime assert type_of(error) == ECReadFailure
        code = error.code
    assert_equal(code, 11)
    try:
        _ = ec_read[LiftAsk[W, ECFixedEnvironment[False]]]()
    except error:
        comptime assert type_of(error) == ECReadFailure
        code = error.code
    assert_equal(code, 22)
    comptime R = ReaderT[IdentityFamily, String]
    var output: Int
    try:
        var deferred = ec_read[LiftAsk[R, ECFixedEnvironment[False]]]()
        output = run[R](deferred^, String("unused"))
    except error:
        raise Error("unexpected construction error")
    assert_equal(output, 8)
    print("Environment capabilities: third-party dictionaries, exact construction errors")
