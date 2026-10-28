"""Conditional recovery reuses handlers while predicates borrow the error."""
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily, ResultFamily, ListFamily
from fp.callables import BorrowCallable
from fp.data import Result, Ok, Err
from fp.effects import Reader, ResultT, run
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


def matches(reason: String) -> Bool: return reason == "missing"
def restore(var reason: String) -> Int: return reason.byte_length()
def retry(var reason: String) -> Result[Int, String]: return Ok(reason.byte_length())


@fieldwise_init
struct Matches(BorrowCallable):
    comptime Payload = String
    comptime Result = Bool
    def invoke(self, ref reason: String) -> Bool: return matches(reason)


def check_basics() raises:
    var fallback = kleisli[IdentityFamily](restore)
    var again = kleisli[ResultFamily[String]](retry)
    assert_equal(Result[Int, String](Err(String("missing"))).recover_if(matches, fallback).raise_on_err(), 7)
    assert_equal(Result[Int, String](Err(String("missing"))).or_else_if(matches, again).raise_on_err(), 7)
    assert_equal(pipeline(Result[Int, String](Err(String("missing")))).recover_if(matches, fallback).raise_on_err(), 7)
    assert_equal(pipeline(Result[Int, String](Err(String("missing")))).or_else_if(matches, again).raise_on_err(), 7)
    assert_equal(pipeline[IdentityFamily](Result[Int, String](Err(String("missing")))).recover(fallback).raise_on_err(), 7)
    assert_equal(pipeline[IdentityFamily](Result[Int, String](Err(String("missing")))).recover_if(matches, fallback).raise_on_err(), 7)
    assert_equal(pipeline[IdentityFamily](Result[Int, String](Err(String("missing")))).or_else_if(matches, again).raise_on_err(), 7)
    assert_equal(Result[Int, String](Err(String("missing"))).recover_if(Matches(), fallback).raise_on_err(), 7)
    assert_equal(pipeline(Result[Int, String](Err(String("missing")))).or_else_if(Matches(), again).raise_on_err(), 7)
    assert_equal(fallback.call(String("reuse")), 5)
    assert_equal(again.call(String("reuse")).raise_on_err(), 5)
    var skipped = Result[Int, String](Err(String("denied"))).or_else_if(matches, again)
    assert_equal(skipped._err().value, "denied")
    def reject(var reason: String) -> Result[Int, String]: return Err(String("retry failed"))
    var failed = kleisli[ResultFamily[String]](reject)
    assert_equal(pipeline(Result[Int, String](Ok(9))).or_else_if(matches, failed).raise_on_err(), 9)
    assert_equal(pipeline(Result[Int, String](Err(String("missing")))).or_else_if(matches, failed).get()._err().value, "retry failed")


def check_selection() raises:
    var predicates = ArcPointer(0)
    var handlers = ArcPointer(0)
    def choose(reason: String) {predicates} -> Bool:
        predicates[] += 1
        return matches(reason)
    def recover(var reason: String) {handlers} -> Int:
        handlers[] += 1
        return restore(reason^)
    var handler = kleisli[IdentityFamily](recover)
    assert_equal(Result[Int, String](Ok(3)).recover_if(choose, handler).raise_on_err(), 3)
    assert_equal(pipeline(Result[Int, String](Ok(5))).recover_if(choose, handler).raise_on_err(), 5)
    assert_equal(predicates[], 0)
    assert_equal(handlers[], 0)
    var kept = Result[Int, String](Err(String("denied"))).recover_if(choose, handler)
    assert_equal(kept._err().value, "denied")
    assert_equal(predicates[], 1)
    assert_equal(handlers[], 0)
    comptime Many = ResultT[ListFamily, String]
    var source: List[Result[Int, String]] = [Ok(2), Err(String("missing")), Err(String("denied")), Err(String("missing"))]
    var recovered = pipeline[Many](source^).recover_if(choose, handler)
    comptime assert type_of(recovered).I == Many
    var results = recovered^.get()
    assert_equal(results[0]._ok().value, 2)
    assert_equal(results[1]._ok().value, 7)
    assert_equal(results[2]._err().value, "denied")
    assert_equal(results[3]._ok().value, 7)
    assert_equal(predicates[], 4)
    assert_equal(handlers[], 2)
    comptime Nested = ResultT[ResultFamily[String], String]
    var outer = Result[Result[Int, String], String](Err(String("outer")))
    assert_equal(pipeline[Nested](outer^).recover_if(choose, handler).get()._err().value, "outer")
    assert_equal(predicates[], 4)
    assert_equal(handlers[], 2)
    comptime Later = ResultT[Reader[Int], String]
    var pending = pipeline[Later](Later.fail[Int](String("missing"))).recover_if(choose, handler).get()
    assert_equal(predicates[], 4)
    assert_equal(handlers[], 2)
    assert_equal(run[Reader[Int]](pending^, 0)._ok().value, 7)
    assert_equal(predicates[], 5)
    assert_equal(handlers[], 3)
    def retry_later(var reason: String) -> Later.Pure[Int]: return Later.pure(reason.byte_length())
    var again = kleisli[Later](retry_later)
    var retried = pipeline[Later](Later.fail[Int](String("missing"))).or_else_if(choose, again).get()
    assert_equal(run[Reader[Int]](retried^, 0)._ok().value, 7)
    var skipped = pipeline[Later](Later.fail[Int](String("denied"))).or_else_if(choose, again).get()
    assert_equal(run[Reader[Int]](skipped^, 0)._err().value, "denied")


def raises_predicate(reason: String) raises Int -> Bool: raise 17

def check_errors() raises:
    var handler = kleisli[IdentityFamily](restore)
    var code = 0
    try: _ = pipeline(Result[Int, String](Err(String("missing")))).raising[Int]().recover_if(raises_predicate, handler).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 17)
    try: _ = Result[Int, String](Err(String("missing"))).recover_if(raises_predicate, handler)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 17)
    def fail(var reason: String) raises Int -> Int: raise 23
    var failed = kleisli[IdentityFamily](fail)
    try: _ = pipeline(Result[Int, String](Err(String("missing")))).raising[String]().recover_if(matches, failed).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 23)
    def choose(reason: String) raises Int -> Bool: return True
    try: _ = Result[Int, String](Err(String("missing"))).recover_if(choose, failed)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 23)


def check_origins(owner: List[Int], errors: List[Int]) raises:
    var view = Span(owner)
    var reason = Span(errors)
    comptime V = type_of(view)
    comptime E = type_of(reason)
    def choose(error: E) -> Bool: return error[0] > 0
    def restore_view(var error: E) {view} -> V: return view
    var handler = kleisli[IdentityFamily](restore_view)
    var recovered = pipeline(Result[V, E](Err(reason))).recover_if(choose, handler).get()
    assert_true(Pointer(to=recovered._ok().value[0]) == Pointer(to=owner[0]))
    def keep(var error: E) -> Result[V, E]: return Err(error)
    var again = kleisli[ResultFamily[E]](keep)
    var retained = Result[V, E](Err(reason)).or_else_if(choose, again)
    assert_true(Pointer(to=retained._err().value[0]) == Pointer(to=errors[0]))


def main() raises:
    check_basics()
    check_selection()
    check_errors()
    check_origins(List[Int]([11, 13]), List[Int]([17, 19]))
