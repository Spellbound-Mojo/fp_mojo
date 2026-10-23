"""Selective recovery shares one guard across eager and deferred families."""
from fp.algebra import ResultFamily, ValidationFamily, ListMonoid, ListFamily, Monad, fail
from fp.effects import ResultT, ReaderT, StateT, WriterT, OptionalT, run, run_writer, writer
from fp.algebra import StringMonoid
from fp.functions import piped, kleisli
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

comptime CER = Result[Int, String]
comptime CEF = ResultFamily[String]


def ce_match(error: String) -> Bool: return error == "retry"
def ce_value(var error: String) -> Int: return 42
def ce_effect(var error: String) -> CER: return Ok(43)
def ce_again(var error: String) -> CER: return Err(String("again"))


def ce_eager() raises:
    assert_equal(piped(fail[CEF, Int](String("retry"))).recover_if[CEF](ce_match, ce_value).get()._ok().value, 42)
    assert_equal(piped(fail[CEF, Int](String("keep"))).recover_if[CEF](ce_match, ce_value).get()._err().value, "keep")
    assert_equal(piped(fail[CEF, Int](String("retry"))).or_else_if[CEF](ce_match, ce_effect).get()._ok().value, 43)
    assert_equal(piped(fail[CEF, Int](String("retry"))).or_else_if[CEF](ce_match, ce_again).get()._err().value, "again")
    var chain = kleisli[CEF](ce_effect)
    assert_equal(piped(fail[CEF, Int](String("retry"))).or_else_if[CEF](ce_match, chain).get()._ok().value, 43)
    var seen = ArcPointer(0)
    def predicate(error: String) {seen} -> Bool:
        seen[] += 1
        return error == "retry"
    def handler(var error: String) {seen} -> Int:
        seen[] += 10
        return 9
    assert_equal(piped(CER(Ok(7))).recover_if[CEF](predicate, handler).get()._ok().value, 7)
    assert_equal(seen[], 0)
    comptime L = ResultT[ListFamily, String]
    var values: List[CER] = [CER(Err(String("keep"))), CER(Ok(1)), CER(Err(String("retry"))), CER(Err(String("retry")))]
    var result = piped(values^).recover_if[L](predicate, handler).get()
    assert_equal(seen[], 23)
    assert_equal(len(result), 4)
    assert_equal(result[0]._err().value, "keep")
    assert_equal(result[1]._ok().value, 1)
    assert_equal(result[3]._ok().value, 9)
    def expand(var error: String) -> List[CER]:
        return List[CER]([CER(Ok(10)), CER(Err(String("replacement")))])
    var branch_source: List[CER] = [CER(Err(String("keep"))), CER(Err(String("retry"))), CER(Ok(3))]
    var branches = piped(branch_source^).or_else_if[L](ce_match, expand).get()
    assert_equal(len(branches), 4)
    assert_equal(branches[0]._err().value, "keep")
    assert_equal(branches[1]._ok().value, 10)
    assert_equal(branches[2]._err().value, "replacement")
    assert_equal(branches[3]._ok().value, 3)
    assert_equal(len(piped(List[CER]()).or_else_if[L](ce_match, expand).get()), 0)
    comptime Nested = ResultT[CEF, String]
    var nested = Result[CER, String](Err(String("outer")))
    var preserved = piped(nested^).recover_if[Nested](predicate, handler).get()
    assert_equal(preserved._err().value, "outer")
    assert_equal(seen[], 23)
    comptime V = ValidationFamily[ListMonoid[String]]
    comptime assert not conforms_to(V, Monad)
    def multiple(errors: List[String]) -> Bool: return len(errors) > 1
    def count(var errors: List[String]) -> Int: return len(errors)
    var errors: List[String] = ["a", "b"]
    assert_equal(piped(fail[V, Int](errors^)).recover_if[V](multiple, count).get()._ok().value, 2)
    var one: List[String] = ["a"]
    assert_equal(piped(fail[V, Int](one^)).recover_if[V](multiple, count).get()._err().value[0], "a")


def ce_transformers() raises:
    comptime R = ReaderT[CEF, Int]
    comptime S = StateT[CEF, Int]
    var calls = ArcPointer(0)
    def predicate(error: String) {calls} -> Bool:
        calls[] += 1
        return error == "retry"
    var reader = piped(fail[R, Int](String("retry"))).recover_if[R](predicate, ce_value).get()
    assert_equal(calls[], 0)
    assert_equal(run[R](reader^, 5)._ok().value, 42)
    assert_equal(calls[], 1)
    var state = piped(fail[S, Int](String("keep"))).recover_if[S](predicate, ce_value).get()
    assert_equal(calls[], 1)
    assert_equal(run[S](state^, 5)._err().value, "keep")
    assert_equal(calls[], 2)
    var state_ok = piped(fail[S, Int](String("retry"))).recover_if[S](predicate, ce_value).get()
    var restored = run[S](state_ok^, 5)
    assert_equal(restored._ok().value[0], 42)
    assert_equal(restored._ok().value[1], 5)
    comptime W = WriterT[CEF, StringMonoid]
    var written = piped(fail[W, Int](String("retry"))).recover_if[W](ce_match, ce_value).get()
    var logged = run_writer[W](written^)
    assert_equal(logged._ok().value[0], "")
    assert_equal(logged._ok().value[1], 42)
    def log_handler(var error: String) -> W.Pure[Int]:
        return writer[W, Int](CEF.pure((String("recovered"), 90)))
    var replacement_log = piped(fail[W, Int](String("retry"))).or_else_if[W](ce_match, log_handler).get()
    var replacement = run_writer[W](replacement_log^)
    assert_equal(replacement._ok().value[0], "recovered")
    assert_equal(replacement._ok().value[1], 90)
    # Effect handlers may have different concrete carrier types from fail.
    def reader_handler(var error: String) -> R.Pure[Int]: return R.pure(55)
    var reader_next = piped(fail[R, Int](String("retry"))).or_else_if[R](predicate, reader_handler).get()
    assert_equal(run[R](reader_next^, 6)._ok().value, 55)
    def state_handler(var error: String) -> S.Pure[Int]: return S.pure(56)
    var state_next = piped(fail[S, Int](String("retry"))).or_else_if[S](predicate, state_handler).get()
    var next = run[S](state_next^, 6)
    assert_equal(next._ok().value[0], 56)
    assert_equal(next._ok().value[1], 6)
    comptime O = OptionalT[CEF]
    var absent = CEF.pure(Optional[Int]())
    assert_true(not piped(absent^).recover_if[O](ce_match, ce_value).get()._ok().value)
    assert_equal(piped(fail[O, Int](String("retry"))).recover_if[O](ce_match, ce_value).get()._ok().value.value(), 42)


def main() raises:
    ce_eager()
    ce_transformers()
    print("conditional error: ok")
