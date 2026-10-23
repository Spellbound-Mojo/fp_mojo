"""Recovery through transformer bases retains their native effects and order."""
from fp.algebra import ApplicativeError, ResultFamily, ListFamily, StringMonoid, fail, pure
from fp.effects import Reader, ReaderT, State, StateT, Writer, WriterT, OptionalT, ResultT, action, run, writer, run_writer
from fp.data import Result, Ok, Err
from fp.functions import piped
from fp.callables import OnceUnary, MutableUnary, BorrowOnceCallable
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, assert_false

comptime AELBase = ResultFamily[String]
comptime AELRead = ReaderT[AELBase, Int]
comptime AELState = StateT[AELBase, Int]


@fieldwise_init
struct AELReadSource(BorrowOnceCallable):
    var calls: ArcPointer[Int]
    var failing: Bool
    comptime Payload = Int
    comptime Result = Result[Int, String]
    def invoke_once(deinit self, ref environment: Int) raises Never capturing -> Self.Result:
        self.calls[] += 1
        if self.failing: return Err(String(environment))
        return Ok(environment)


@fieldwise_init
struct AELRestoreRead(BorrowOnceCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = Result[Int, String]
    def invoke_once(deinit self, ref environment: Int) raises Never capturing -> Self.Result:
        self.calls[] += 1
        return Ok(environment + 10)


@fieldwise_init
struct AELStateSource(OnceUnary):
    var failing: Bool
    comptime Arg = Int
    comptime Out = Result[Tuple[Int, Int], String]
    def call_once(deinit self, var state: Int) -> Self.Out:
        state += 100
        if self.failing: return Err(String(state))
        return Ok((state, state))


@fieldwise_init
struct AELRestoreState(OnceUnary, Defaultable):
    comptime Arg = Int
    comptime Out = Result[Tuple[Int, Int], String]
    def call_once(deinit self, var state: Int) -> Self.Out:
        return Ok((state, state + 1))


def ael_reader() raises:
    comptime assert conforms_to(AELRead, ApplicativeError)
    comptime assert not conforms_to(Reader[Int], ApplicativeError)
    var calls = ArcPointer(0)
    comptime Next = type_of(action[AELRead, Int](AELRestoreRead(calls)))
    def restore(var error: String) {calls} -> Next:
        calls[] += 1
        return action[AELRead, Int](AELRestoreRead(calls))
    var pending = piped(action[AELRead, Int](AELReadSource(calls, True))).or_else[AELRead](restore).get()
    assert_equal(calls[], 0)
    var env = 7
    assert_equal(run[AELRead](pending^, env)._ok().value, 17)
    assert_equal(calls[], 3)
    var successful = piped(action[AELRead, Int](AELReadSource(calls, False))).or_else[AELRead](restore).get()
    assert_equal(run[AELRead](successful^, env)._ok().value, 7)
    assert_equal(calls[], 4)
    def fallback(var error: String) -> Int: return 9
    var failed = piped(fail[AELRead, Int](String("missing"))).recover[AELRead](fallback).get()
    assert_equal(run[AELRead](failed^, env)._ok().value, 9)


def ael_state() raises:
    comptime assert conforms_to(AELState, ApplicativeError)
    comptime assert not conforms_to(State[Int], ApplicativeError)
    comptime Next = type_of(action[AELState, Int](AELRestoreState()))
    def restore(var error: String) -> Next: return action[AELState, Int](AELRestoreState())
    var pending = piped(action[AELState, Int](AELStateSource(True))).or_else[AELState](restore).get()
    assert_equal(run[AELState](pending^, 5)._ok().value, (5, 6))
    var successful = piped(action[AELState, Int](AELStateSource(False))).or_else[AELState](restore).get()
    assert_equal(run[AELState](successful^, 5)._ok().value, (105, 105))
    def fallback(var error: String) -> Int: return 9
    var failed = piped(fail[AELState, Int](String("missing"))).recover[AELState](fallback).get()
    assert_equal(run[AELState](failed^, 5)._ok().value, (9, 5))


def ael_optional_writer() raises:
    comptime O = OptionalT[AELBase]
    comptime assert conforms_to(O, ApplicativeError)
    comptime assert not conforms_to(OptionalT[ListFamily], ApplicativeError)
    def optional(var error: String) -> Result[Optional[Int], String]: return Ok(Optional(8))
    assert_equal(piped(fail[O, Int](String("bad"))).or_else[O](optional).get()._ok().value.value(), 8)
    var absent = piped(Result[Optional[Int], String](Ok(Optional[Int]()))).or_else[O](optional).get()
    assert_false(absent._ok().value)
    def value(var error: String) -> Int: return 12
    assert_equal(piped(fail[O, Int](String("bad"))).recover[O](value).get()._ok().value.value(), 12)
    comptime W = WriterT[AELBase, StringMonoid]
    comptime assert conforms_to(W, ApplicativeError)
    comptime assert not conforms_to(Writer[StringMonoid], ApplicativeError)
    comptime Next = type_of(writer[W, Int](Result[Tuple[String, Int], String](Ok((String("handler"), 6)))))
    def logged(var error: String) -> Next:
        return writer[W, Int](Result[Tuple[String, Int], String](Ok((String("handler"), 6))))
    var recovered = piped(fail[W, Int](String("bad"))).or_else[W](logged).get()
    assert_equal(run_writer[W](recovered^)._ok().value, (String("handler"), 6))
    var source = writer[W, Int](Result[Tuple[String, Int], String](Ok((String("source"), 2))))
    var kept = piped(source^).or_else[W](logged).get()
    assert_equal(run_writer[W](kept^)._ok().value, (String("source"), 2))


def main() raises:
    ael_reader()
    ael_state()
    ael_optional_writer()
    ael_boundary_and_branches()
    ael_nested()
    ael_nested_environment()
    print("applicative error lifting: ok")


@fieldwise_init
struct AELBoundary(OnceUnary, Defaultable):
    comptime Arg = Int
    comptime Handler = AELBoundaryHandler
    comptime Source = type_of(action[AELState, Int](AELStateSource(True)))
    comptime Out = AELState.Handled[Self.Source, Self.Handler]
    def call_once(deinit self, var value: Int) -> Self.Out:
        return piped(action[AELState, Int](AELStateSource(True))).or_else[AELState](Self.Handler()).get()


@fieldwise_init
struct AELBoundaryHandler(OnceUnary, Defaultable):
    comptime Arg = String
    comptime Out = type_of(action[AELState, Int](AELRestoreState()))
    def call_once(deinit self, var error: String) -> Self.Out:
        return action[AELState, Int](AELRestoreState())


comptime AELBranches = StateT[ResultT[ListFamily, String], Int]


@fieldwise_init
struct AELBranchSource(OnceUnary, Defaultable):
    comptime Arg = Int
    comptime Out = List[Result[Tuple[Int, Int], String]]
    def call_once(deinit self, var state: Int) -> Self.Out:
        comptime Item = Result[Tuple[Int, Int], String]
        return List[Item]([Item(Ok((state + 1, state + 100))), Item(Err(String("a"))), Item(Err(String("b")))])


@fieldwise_init
struct AELBranchRestore(OnceUnary, Defaultable):
    comptime Arg = Int
    comptime Out = List[Result[Tuple[Int, Int], String]]
    def call_once(deinit self, var state: Int) -> Self.Out:
        comptime Item = Result[Tuple[Int, Int], String]
        return List[Item]([Item(Ok((state, state + 1)))])


@fieldwise_init
struct AELBranchHandler(MutableUnary):
    var calls: ArcPointer[Int]
    comptime Arg = String
    comptime Out = type_of(action[AELBranches, Int](AELBranchRestore()))
    def call_mut(mut self, var error: String) -> Self.Out:
        self.calls[] += 1
        return action[AELBranches, Int](AELBranchRestore())


def ael_boundary_and_branches() raises:
    var composed = piped(action[AELState, Int](AELStateSource(False))).flat_map[AELState](AELBoundary()).get()
    assert_equal(run[AELState](composed^, 5)._ok().value, (105, 106))
    var calls = ArcPointer(0)
    var branches = piped(action[AELBranches, Int](AELBranchSource())).or_else[AELBranches](AELBranchHandler(calls)).get()
    assert_equal(calls[], 0)
    var outputs = run[AELBranches](branches^, 5)
    assert_equal(calls[], 2)
    assert_equal(len(outputs), 3)
    assert_equal(outputs[0]._ok().value, (6, 105))
    assert_equal(outputs[1]._ok().value, (5, 6))
    assert_equal(outputs[2]._ok().value, (5, 6))


def ael_nested() raises:
    comptime OuterReader = ReaderT[ResultT[AELBase, String], Int]
    def fallback(var error: String) -> Int: return 10
    var inner = piped(fail[OuterReader, Int](String("inner"))).recover[OuterReader](fallback).get()
    var environment = 5
    assert_equal(run[OuterReader](inner^, environment)._ok().value._ok().value, 10)
    var outer_error = Result[Result[Int, String], String](Err(String("outer")))
    var outer = piped(OuterReader.lift(outer_error^)).recover[OuterReader](fallback).get()
    assert_equal(run[OuterReader](outer^, environment)._err().value, "outer")
    comptime O = OptionalT[AELRead]
    var optional = piped(fail[O, Int](String("bad"))).recover[O](fallback).get()
    assert_equal(run[AELRead](optional^, environment)._ok().value.value(), 10)
    var absent = piped(pure[AELRead](Optional[Int]())).recover[O](fallback).get()
    assert_false(run[AELRead](absent^, environment)._ok().value)
    comptime W = WriterT[AELRead, StringMonoid]
    var logged = piped(fail[W, Int](String("bad"))).recover[W](fallback).get()
    var base = run_writer[W](logged^)
    assert_equal(run[AELRead](base^, environment)._ok().value, (String(), 10))
    # The base below State may itself be deferred.
    comptime S = StateT[AELRead, Int]
    var state = piped(fail[S, Int](String("bad"))).recover[S](fallback).get()
    var read = run[S](state^, 8)
    assert_equal(run[AELRead](read^, environment)._ok().value, (10, 8))


comptime AELInnerRead = ReaderT[AELBase, Int]
comptime AELOuterRead = ReaderT[AELInnerRead, String]


@fieldwise_init
struct AELNestedRead(BorrowOnceCallable):
    var calls: ArcPointer[Int]
    comptime Payload = String
    comptime Result = AELInnerRead.Pure[Int]
    def invoke_once(deinit self, ref environment: String) raises Never capturing -> Self.Result:
        self.calls[] += 1
        return pure[AELInnerRead](environment.byte_length())


def ael_nested_environment() raises:
    var calls = ArcPointer(0)
    comptime Next = type_of(action[AELOuterRead, Int](AELNestedRead(calls)))
    def restore(var error: String) {calls} -> Next:
        calls[] += 1
        return action[AELOuterRead, Int](AELNestedRead(calls))
    var pending = piped(fail[AELOuterRead, Int](String("bad"))).or_else[AELOuterRead](restore).get()
    var outer_environment = String("configuration")
    var inner = run[AELOuterRead](pending^, outer_environment)
    assert_equal(calls[], 0)
    assert_equal(run[AELInnerRead](inner^, 0)._ok().value, 13)
    assert_equal(calls[], 2)
