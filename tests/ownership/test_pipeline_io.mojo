"""IO pipelines move success, error and cleanup captures through one owner."""
from fp.functions import pipeline
from fp.effects import delay, CancellationToken
from fp.callables import OnceThunk
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_true

@fieldwise_init
struct OwnedStep(OnceThunk):
    var value: Token
    var fail: Bool
    comptime Out = Token
    comptime Error = Token
    def call_once(deinit self) raises Token -> Token:
        self.value.trace[].calls += 1
        if self.fail: raise self.value^
        return self.value^

def skipped[abandoned: Bool]() raises:
    var record = trace()
    var program = pipeline(delay[Token](OwnedStep(Token(1, record), False))).guarantee(delay[Token](OwnedStep(Token(2, record), False)))
    comptime if abandoned:
        _ = program^
    else:
        var token = CancellationToken()
        token.cancel()
        var result = program^.run_io(token)
        assert_true(not result)
    assert_equal(record[].calls, 0)
    assert_equal(record[].drops[1], 1)
    assert_equal(record[].drops[2], 1)

def main() raises:
    skipped[False]()
    skipped[True]()
    var record = trace()
    var result = pipeline(delay[Token](OwnedStep(Token(1, record), False))).guarantee(delay[Token](OwnedStep(Token(2, record), False))).run_io()
    assert_equal(record[].calls, 2)
    assert_equal(record[].drops[1], 0)
    assert_equal(record[].drops[2], 1)
    _ = result^
    assert_equal(record[].drops[1], 1)
    var failed = pipeline(delay[Token](OwnedStep(Token(3, record), True))).guarantee(delay[Token](OwnedStep(Token(4, record), True))).run_io()
    assert_equal(record[].calls, 4)
    assert_equal(record[].drops[3], 0)
    assert_equal(record[].drops[4], 0)
    var outcome = failed.take()
    assert_true(outcome.is_err())
    var errors: List[Token]
    try:
        errors = outcome^.swap().raise_on_err().into_errors().into_list()
    except:
        raise Error("expected retained move-only failures")
    assert_equal(len(errors), 2)
    assert_equal(errors[0].id, 3)
    assert_equal(errors[1].id, 4)
    _ = errors^
    assert_equal(record[].drops[3], 1)
    assert_equal(record[].drops[4], 1)
