"""Family ensure admits native/library mixtures and preserves generic errors."""
from fp.functions import pipeline
from fp.algebra import ErrorRecovery, Functor, ApplicativeError, ErrorMapping, IdentityFamily, ResultFamily
from fp.data import Result, Ok
from fp.effects import Reader, ResultT, run
from std.testing import assert_equal
from std.memory import ArcPointer
from test_context_family_ensure import Positive, Label, Family


def generic[A: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable, P: def(A) raises X -> Bool, G: def(A) raises X -> E](var source: Result[A,E], predicate: P, factory: G) raises X -> Result[A,E]:
    return pipeline(source^).raising[X]().ensure(predicate,factory).get()


def intrinsic[A: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable, P: def(A) raises X -> Bool, G: def(A) raises X -> E, //, I: Functor](var source: Result[A,E], predicate: P, factory: G) raises X -> Result[A,E] where not conforms_to(I,ErrorRecovery) and not conforms_to(I, ErrorMapping):
    return pipeline[I](source^).raising[X]().ensure(predicate,factory).get()


def predicate_pure[A: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable, P: def(A) -> Bool, G: def(A) raises X -> E](var source: Result[A,E], predicate: P, factory: G) raises X -> Result[A,E]:
    return pipeline(source^).raising[X]().ensure(predicate,factory).get()

def factory_pure[A: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable, P: def(A) raises X -> Bool, G: def(A) -> E](var source: Result[A,E], predicate: P, factory: G) raises X -> Result[A,E]:
    return pipeline(source^).raising[X]().ensure(predicate,factory).get()

def reject(value: Int) -> Bool: return False
def label(value: Int) -> String: return String(value)
def never_reject(value: Int) raises Never -> Bool: return False
def never_label(value: Int) raises Never -> String: return String(value)
def typed_reject(value: Int) raises Int -> Bool: return False
def typed_label(value: Int) raises Int -> String: return String(value)
def failed_predicate(value: Int) raises Int -> Bool: raise 743
def failed_factory(value: Int) raises Int -> String: raise 745


def exact_errors() raises:
    var code = 0
    var value = Result[Int,String](Ok(0))
    try: value = generic(Result[Int,String](Ok(-1)),typed_reject,typed_label)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,0)
    assert_equal(value._err().value,"-1")
    try: value = intrinsic[I=IdentityFamily](Result[Int,String](Ok(-2)),typed_reject,typed_label)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,0)
    assert_equal(value._err().value,"-2")
    var tag = String("never")
    def pure_predicate(value: Int) raises Never {tag} -> Bool: return tag == "accepted"
    def pure_factory(value: Int) raises Never {tag} -> String: return tag
    assert_equal(generic(Result[Int,String](Ok(-3)),pure_predicate,pure_factory)._err().value,"never")
    assert_equal(intrinsic[I=IdentityFamily](Result[Int,String](Ok(-4)),pure_predicate,pure_factory)._err().value,"never")
    try: _ = generic(Result[Int,String](Ok(-5)),failed_predicate,typed_label)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,743)
    try: value = predicate_pure(Result[Int,String](Ok(-6)),reject,typed_label)
    except _: raise Error("unexpected mixed factory failure")
    assert_equal(value._err().value,"-6")
    try: value = factory_pure(Result[Int,String](Ok(-7)),typed_reject,label)
    except _: raise Error("unexpected mixed predicate failure")
    assert_equal(value._err().value,"-7")
    try: _ = predicate_pure(Result[Int,String](Ok(-8)),reject,failed_factory)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,745)


def native_families() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    var tests = ArcPointer(0)
    var errors = ArcPointer(0)
    var mixed = pipeline[I](I.pure(-1)).ensure(Positive(tests),label).get()
    assert_equal(tests[],0)
    assert_equal(run[R](mixed^,0)._err().value,"-1")
    assert_equal(tests[],1)
    var other = pipeline[I](I.pure(-2)).ensure(reject,Label(errors)).get()
    assert_equal(errors[],0)
    assert_equal(run[R](other^,0)._err().value,"-2")
    assert_equal(errors[],1)
    var pointer: def(Int) thin -> String = label
    var stored = pipeline[I](I.pure(-3)).ensure(reject,pointer).get()
    def changed(value: Int) -> String: return String("changed")
    pointer = changed
    assert_equal(pointer(1),"changed")
    assert_equal(run[R](stored^,0)._err().value,"-3")
    var captured_calls = 0
    def captured(value: Int) {mut captured_calls} -> Bool:
        captured_calls += 1
        return False
    var pending = pipeline[I](I.pure(-4)).ensure(captured,label).get()
    assert_equal(captured_calls,0)
    assert_equal(run[R](pending^,0)._err().value,"-4")
    assert_equal(captured_calls,1)
    assert_equal(pipeline[Family[]](Result[Int,String](Ok(-5))).ensure(reject,label).get()._err().value,"custom:-5")
    var fail_predicate = pipeline[I](I.pure(2)).raising[Int]().ensure(failed_predicate,Label(errors)).get()
    var code = 0
    try: _ = run[R](fail_predicate^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,743)
    assert_equal(errors[],1)
    var fail_factory = pipeline[I](I.pure(2)).raising[Int]().ensure(Positive(tests),failed_factory).get()
    # Positive success skips the raising factory entirely.
    try: _ = run[R](fail_factory^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,743)
    var rejected = pipeline[I](I.pure(-2)).raising[Int]().ensure(Positive(tests),failed_factory).get()
    try: _ = run[R](rejected^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,745)


def main() raises:
    exact_errors()
    native_families()
