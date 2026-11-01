"""Selected ensure preserves family construction, branching and deferred timing."""
from fp.algebra import Applicative, ApplicativeError, Monad, ResultFamily, ListFamily
from fp.algebra.contracts import EnsureContract
from fp.callables import BorrowCallContract, BorrowCallable, UnaryContract, BinaryContract, ThunkContract
from fp.functions import pipeline, Pipeline
from fp.data import Result, Ok, Err
from fp.effects import Reader, State, ReaderT, ResultT, run
from std.memory import ArcPointer
from std.builtin.rebind import downcast, rebind_var
from std.testing import assert_equal


def checked[I: ApplicativeError & Monad, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, G: BorrowCallContract & Movable & Deinitable](var source: V, var predicate: P, var factory: G) raises EnsureContract[I,V,P,G].Error -> Pipeline[EnsureContract[I,V,P,G].Family,EnsureContract[I,V,P,G].Out] where EnsureContract[I,V,P,G].Compatible:
    return pipeline[I](source^).ensure(predicate^,factory^)


def expanded[I: ApplicativeError & Monad, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, G: BorrowCallContract & Movable & Deinitable](var source: V, var predicate: P, var factory: G) raises EnsureContract[I,V,P,G].Error -> EnsureContract[I,V,P,G].Out where P.Payload == I.Element[V] and G.Payload == I.Element[V] and P.Result == Bool and G.Result == I.Failure and I._ErrorCarrier[V] and (P.Failure == Never or G.Failure == Never or P.Failure == G.Failure) and I.BindCompatible[V, EnsureContract[I,V,P,G].Continuation]:
    return checked[I](source^,predicate^,factory^).get()


def forwarded[I: ApplicativeError & Monad, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, G: BorrowCallContract & Movable & Deinitable](var source: V, var predicate: P, var factory: G) raises EnsureContract[I,V,P,G].Error -> EnsureContract[I,V,P,G].Out where EnsureContract[I,V,P,G].Compatible:
    return expanded[I](source^,predicate^,factory^)


def conditional[I: Applicative, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, G: BorrowCallContract & Movable & Deinitable](var source: V, var predicate: P, var factory: G) raises EnsureContract[downcast[I,ApplicativeError & Monad],V,P,G].Error -> EnsureContract[downcast[I,ApplicativeError & Monad],V,P,G].Out where conforms_to(I,ApplicativeError & Monad) and EnsureContract[downcast[I,ApplicativeError & Monad],V,P,G].Compatible:
    return pipeline[I](source^).ensure(predicate^,factory^).get()


@fieldwise_init
struct Positive(BorrowCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = Bool
    def invoke(self, ref value: Int) -> Bool:
        self.calls[] += 1
        return value > 0


@fieldwise_init
struct Label(BorrowCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = String
    def invoke(self, ref value: Int) -> String:
        self.calls[] += 1
        return String(value)


# Native Result storage cannot stand in for this family's own failure and bind.
struct Family[fail_raises: Bool = False, bind_raises: Bool = False, admitted: Bool = True](ApplicativeError, Monad):
    comptime Base = ResultFamily[String]
    comptime Element[V: Movable & Deinitable] = Self.Base.Element[V]
    comptime Pure[A: Movable & Deinitable] = Self.Base.Pure[A]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.Combined[V,F,R]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.CombineError[V,F,R]
    comptime Failure = String
    comptime Failed[A: Movable & Deinitable] = Self.Base.Failed[A]
    comptime FailError[A: Movable & Deinitable] = Int if Self.fail_raises else Never
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Base.Handled[V,H]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Base.HandleError[V,H]
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.Base._ErrorCarrier[V]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Bound[V,F]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Int if Self.bind_raises else F.Error
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.admitted and Self.Base.BindCompatible[V,F]
    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]: return Self.Base.pure(value^)
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]: return Self.Base.map(f^,value^)
    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var f: F, var left: V, var right: R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]: return Self.Base.map2_lazy(f^,left^,right^)
    @staticmethod
    def fail[A: Movable & Deinitable](var error: String) raises Self.FailError[A] -> Self.Failed[A]:
        comptime if Self.fail_raises:
            comptime assert Self.FailError[A] == Int
            raise rebind_var[Self.FailError[A]](Int(731))
        else: return Self.Base.fail[A](String("custom:") + error)
    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Self.HandleError[V,H] -> Self.Handled[V,H]: return Self.Base.or_else(handler^,source^)
    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V) raises Self.BindError[V,F] -> Self.Bound[V,F]:
        comptime if Self.bind_raises:
            comptime assert Self.BindError[V,F] == Int
            raise rebind_var[Self.BindError[V,F]](Int(733))
        else:
            comptime assert Self.BindError[V,F] == F.Error
            try: return Self.Base.flat_map(f^,source^)
            except error:
                comptime assert Self.BindError[V,F] == type_of(error)
                raise rebind_var[Self.BindError[V,F]](error^)


def custom_family() raises:
    var tests = ArcPointer(0)
    var errors = ArcPointer(0)
    var selected = checked[Family[]](Result[Int,String](Ok(-1)), Positive(tests), Label(errors))
    comptime assert type_of(selected).I == Family[]
    assert_equal(selected^.get()._err().value, "custom:-1")
    assert_equal(tests[],1)
    assert_equal(errors[],1)
    var code = 0
    try: _ = checked[Family[True]](Result[Int,String](Ok(-2)), Positive(tests), Label(errors)).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,731)
    assert_equal(tests[],2)
    assert_equal(errors[],2)
    try: _ = checked[Family[False,True]](Result[Int,String](Ok(4)), Positive(tests), Label(errors)).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,733)
    assert_equal(tests[],2)
    assert_equal(errors[],2)


def deferred() raises:
    var tests = ArcPointer(0)
    var errors = ArcPointer(0)
    comptime R = Reader[Int]
    comptime T = ResultT[R,String]
    var pending = checked[T](T.pure(-3),Positive(tests),Label(errors)).get()
    assert_equal(tests[],0)
    assert_equal(errors[],0)
    assert_equal(run[R](pending^,7)._err().value,"-3")
    assert_equal(tests[],1)
    assert_equal(errors[],1)
    var skipped = checked[T](T.fail[Int](String("old")),Positive(tests),Label(errors)).get()
    assert_equal(run[R](skipped^,7)._err().value,"old")
    assert_equal(tests[],1)
    assert_equal(errors[],1)
    comptime S = State[Int]
    comptime ST = ResultT[S,String]
    var state = checked[ST](ST.pure(5),Positive(tests),Label(errors)).get()
    assert_equal(tests[],1)
    var result = run[S](state^,11)
    assert_equal(result[0]._ok().value,5)
    assert_equal(result[1],11)
    assert_equal(tests[],2)
    assert_equal(errors[],1)
    comptime RT = ReaderT[ResultFamily[String],Int]
    var reader = checked[RT](RT.pure(-4),Positive(tests),Label(errors)).get()
    assert_equal(run[RT](reader^,0)._err().value,"-4")


def branching() raises:
    var tests = ArcPointer(0)
    var errors = ArcPointer(0)
    comptime I = ResultT[ListFamily,String]
    var source = List[Result[Int,String]]([Result[Int,String](Ok(2)),Result[Int,String](Ok(-2)),Result[Int,String](Err(String("old")))])
    var result = checked[I](source^,Positive(tests),Label(errors)).get()
    assert_equal(result[0]._ok().value,2)
    assert_equal(result[1]._err().value,"-2")
    assert_equal(result[2]._err().value,"old")
    assert_equal(tests[],2)
    assert_equal(errors[],1)


def main() raises:
    var predicates = ArcPointer(0)
    var factories = ArcPointer(0)
    assert_equal(forwarded[ResultFamily[String]](Result[Int,String](Ok(7)),Positive(predicates),Label(factories))._ok().value,7)
    comptime Conditional = ReaderT[ResultFamily[String],Int]
    var conditional_result = conditional[Conditional](Conditional.pure(-7),Positive(predicates),Label(factories))
    assert_equal(run[Conditional](conditional_result^,0)._err().value,"-7")
    custom_family()
    deferred()
    branching()
