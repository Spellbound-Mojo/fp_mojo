"""Shared recovery selects one stored-error layer and preserves base effects."""
from fp.algebra import ApplicativeError, Monad, ResultFamily, ValidationFamily, ListFamily, ListMonoid, fail
from fp.effects import ResultT, Reader, State, Writer, action, run, writer, run_writer
from fp.algebra import StringMonoid
from fp.functions import piped, kleisli
from fp.callables import MutableUnary, OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

comptime AER = Result[Int, String]
comptime AEF = ResultFamily[String]


def ae_value(var error: String) -> Int: return error.byte_length()
def ae_effect(var error: String) -> AER: return Ok(error.byte_length())
def ae_again(var error: String) -> AER: return Err(error + "!")


@fieldwise_init
struct AEBranches(MutableUnary):
    var seen: ArcPointer[Int]
    comptime Arg = String
    comptime Out = List[AER]
    def call_mut(mut self, var error: String) -> Self.Out:
        self.seen[] += 1
        if error == "drop": return List[AER]()
        return List[AER]([AER(Ok(self.seen[])), AER(Err(error^))])


def ae_direct() raises:
    assert_true(conforms_to(AEF, ApplicativeError))
    assert_equal(fail[AEF, Int](String("bad"))._err().value, "bad")
    assert_equal(piped(fail[AEF, Int](String("bad"))).recover[AEF](ae_value).get()._ok().value, 3)
    assert_equal(piped(fail[AEF, Int](String("bad"))).or_else[AEF](ae_effect).get()._ok().value, 3)
    assert_equal(piped(fail[AEF, Int](String("bad"))).or_else[AEF](ae_again).get()._err().value, "bad!")
    var calls = ArcPointer(0)
    def counted(var error: String) {calls} -> Int:
        calls[] += 1
        return 8
    assert_equal(piped(AER(Ok(7))).recover[AEF](counted).get()._ok().value, 7)
    assert_equal(calls[], 0)
    var chain = kleisli[AEF](ae_effect)
    assert_equal(piped(fail[AEF, Int](String("four"))).or_else[AEF](chain).get()._ok().value, 4)
    def raised(var error: String) raises Int -> Int: raise 91
    var code = 0
    try:
        _ = piped(fail[AEF, Int](String("bad"))).recover[AEF](raised).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 91)
    # Existing inferred Result recovery still admits a changed stored-error type.
    def changed(var error: String) -> Result[Int, Int]: return Err(error.byte_length())
    assert_equal(piped(fail[AEF, Int](String("bad"))).or_else(changed).get()._err().value, 3)
    comptime V = ValidationFamily[ListMonoid[String]]
    comptime assert conforms_to(V, ApplicativeError) and not conforms_to(V, Monad)
    def count(var errors: List[String]) -> Int: return len(errors)
    var errors: List[String] = ["first", "second"]
    assert_equal(piped(fail[V, Int](errors^)).recover[V](count).get()._ok().value, 2)


def ae_layers() raises:
    comptime L = ResultT[ListFamily, String]
    var calls = ArcPointer(0)
    var items: List[AER] = [AER(Ok(8)), AER(Err(String("a"))), AER(Err(String("drop"))), AER(Err(String("b"))), AER(Ok(9))]
    var handled = piped(items^).or_else[L](AEBranches(calls)).get()
    assert_equal(calls[], 3)
    assert_equal(len(handled), 6)
    assert_equal(handled[0]._ok().value, 8)
    assert_equal(handled[1]._ok().value, 1)
    assert_equal(handled[2]._err().value, "a")
    assert_equal(handled[3]._ok().value, 3)
    assert_equal(handled[4]._err().value, "b")
    assert_equal(handled[5]._ok().value, 9)
    var no_items = piped(List[AER]()).or_else[L](AEBranches(calls)).get()
    assert_equal(len(no_items), 0)
    assert_equal(calls[], 3)
    var recovered = piped(List[AER]([AER(Err(String("abc"))), AER(Ok(4))])).recover[L](ae_value).get()
    assert_equal(recovered[0]._ok().value, 3)
    assert_equal(recovered[1]._ok().value, 4)
    comptime Nested = ResultT[AEF, String]
    comptime NR = Result[AER, String]
    def nested(var error: String) -> NR: return Ok(AER(Ok(20)))
    var inner = piped(NR(Ok(AER(Err(String("inner")))))).or_else[Nested](nested).get()
    assert_equal(inner._ok().value._ok().value, 20)
    var outer = piped(NR(Err(String("outer")))).or_else[Nested](nested).get()
    assert_equal(outer._err().value, "outer")
    comptime Distinct = ResultT[ResultFamily[Int], String]
    var distinct = piped(Result[AER, Int](Err(99))).recover[Distinct](ae_value).get()
    assert_equal(distinct._err().value, 99)
    assert_equal(fail[L, Int](String("one"))[0]._err().value, "one")


@fieldwise_init
struct AERead(BorrowOnceCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = AER
    def invoke_once(deinit self, ref environment: Int) raises Never capturing -> AER:
        self.calls[] += 1
        return Ok(environment + 1)


@fieldwise_init
struct AEState(OnceUnary):
    comptime Arg = Int
    comptime Out = Tuple[AER, Int]
    def call_once(deinit self, var state: Int) -> Self.Out:
        return (AER(Err(String("updated"))), state + 10)


def ae_deferred() raises:
    comptime R = Reader[Int]
    comptime L = ResultT[R, String]
    var calls = ArcPointer(0)
    comptime RA = type_of(action[R, AER](AERead(calls)))
    def handler(var error: String) {calls} -> RA:
        calls[] += 1
        return action[R, AER](AERead(calls))
    var recovered = piped(fail[L, Int](String("bad"))).or_else[L](handler).get()
    assert_equal(calls[], 0)
    var env = 7
    assert_equal(run[R](recovered^, env)._ok().value, 8)
    assert_equal(calls[], 2)
    def raised(var error: String) raises Int -> Int: raise 77
    var failing = piped(fail[L, Int](String("bad"))).recover[L](raised).get()
    var code = 0
    try:
        _ = run[R](failing^, env)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 77)
    comptime S = State[Int]
    comptime T = ResultT[S, String]
    var state = piped(action[S, AER](AEState())).recover[T](ae_value).get()
    var result = run[S](state^, 5)
    assert_equal(result[0]._ok().value, 7)
    assert_equal(result[1], 15)
    comptime W = Writer[StringMonoid]
    comptime WT = ResultT[W, String]
    comptime WA = type_of(writer[W, AER]((String(), AER(Ok(0)))))
    def log(var error: String) -> WA: return writer[W, AER]((String("b"), AER(Ok(6))))
    var logged = piped(writer[W, AER]((String("a"), AER(Err(String("bad")))))).or_else[WT](log).get()
    var output = run_writer[W](logged^)
    assert_equal(output[0], "ab")
    assert_equal(output[1]._ok().value, 6)


def main() raises:
    ae_direct()
    ae_layers()
    ae_deferred()
    print("applicative error: ok")
