"""Generic conditional recovery forwards public contracts and native errors."""
from fp.algebra import ErrorRecovery, Functor, Applicative, ApplicativeError, ErrorMapping, IdentityFamily, ResultFamily
from fp.algebra.contracts import RecoverIfContract, OrElseIfContract
from fp.callables import BorrowCallContract, BorrowCallable, UnaryContract, Unary
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.builtin.rebind import downcast


def recovered[I: ApplicativeError, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var predicate: P, var handler: H) raises RecoverIfContract[I,V,P,H].Error -> RecoverIfContract[I,V,P,H].Out where RecoverIfContract[I,V,P,H].Compatible:
    return pipeline[I](source^).recover_if(predicate^,handler^).get()


def replaced[I: ApplicativeError, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var predicate: P, var handler: H) raises OrElseIfContract[I,V,P,H].Error -> OrElseIfContract[I,V,P,H].Out where OrElseIfContract[I,V,P,H].Compatible:
    return pipeline[I](source^).or_else_if(predicate^,handler^).get()


def expanded[I: ApplicativeError, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var predicate: P, var handler: H) raises RecoverIfContract[I,V,P,H].Error -> RecoverIfContract[I,V,P,H].Out where P.Payload == I.Failure and H.Arg == I.Failure and P.Result == Bool and I._ErrorCarrier[V] and H.Out == I.Element[V] and RecoverIfContract[I,V,P,H].NativeErrorsCompatible and RecoverIfContract[I,V,P,H].ReceiverCompatible and RecoverIfContract[I,V,P,H].OperationCompatible:
    return recovered[I](source^,predicate^,handler^)


def expanded_effect[I: ApplicativeError, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var predicate: P, var handler: H) raises OrElseIfContract[I,V,P,H].Error -> OrElseIfContract[I,V,P,H].Out where P.Payload == I.Failure and H.Arg == I.Failure and P.Result == Bool and I._ErrorCarrier[V] and I._ErrorCarrier[H.Out] and I.Element[H.Out] == I.Element[V] and OrElseIfContract[I,V,P,H].NativeErrorsCompatible and OrElseIfContract[I,V,P,H].ReceiverCompatible and OrElseIfContract[I,V,P,H].OperationCompatible:
    return replaced[I](source^,predicate^,handler^)


def witnessed[I: Applicative, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var predicate: P, var handler: H) raises RecoverIfContract[downcast[I,ApplicativeError],V,P,H].Error -> RecoverIfContract[downcast[I,ApplicativeError],V,P,H].Out where conforms_to(I,ApplicativeError) and RecoverIfContract[downcast[I,ApplicativeError],V,P,H].Compatible:
    return pipeline[I](source^).recover_if(predicate^,handler^).get()


def native_recovered[A: Movable & Deinitable, F: Movable & Deinitable, E: Movable & Deinitable, //, P: def(F) raises E -> Bool, H: def(var F) raises E -> A](var source: Result[A,F], predicate: P, handler: H) raises E -> Result[A,F]:
    return pipeline(source^).raising[E]().recover_if(predicate,handler).get()


def native_replaced[A: Movable & Deinitable, F: Movable & Deinitable, E: Movable & Deinitable, //, P: def(F) raises E -> Bool, H: def(var F) raises E -> Result[A,F]](var source: Result[A,F], predicate: P, handler: H) raises E -> Result[A,F]:
    return pipeline(source^).raising[E]().or_else_if(predicate,handler).get()


def mixed_handler[A: Movable & Deinitable, F: Movable & Deinitable, E: Movable & Deinitable, //, P: def(F) -> Bool, H: def(var F) raises E -> A](var source: Result[A,F], predicate: P, handler: H) raises E -> Result[A,F]:
    return pipeline(source^).raising[E]().recover_if(predicate,handler).get()


def mixed_predicate[A: Movable & Deinitable, F: Movable & Deinitable, E: Movable & Deinitable, //, P: def(F) raises E -> Bool, H: def(var F) -> A](var source: Result[A,F], predicate: P, handler: H) raises E -> Result[A,F]:
    return pipeline(source^).raising[E]().recover_if(predicate,handler).get()


def intrinsic_recovered[A: Movable & Deinitable, F: Movable & Deinitable, E: Movable & Deinitable, //, I: Functor, P: def(F) raises E -> Bool, H: def(var F) raises E -> A](var source: Result[A,F], predicate: P, handler: H) raises E -> Result[A,F] where not conforms_to(I,ErrorRecovery) and not conforms_to(I, ErrorMapping):
    return pipeline[I](source^).raising[E]().recover_if(predicate,handler).get()


def intrinsic_replaced[A: Movable & Deinitable, F: Movable & Deinitable, E: Movable & Deinitable, //, I: Functor, P: def(F) raises E -> Bool, H: def(var F) raises E -> Result[A,F]](var source: Result[A,F], predicate: P, handler: H) raises E -> Result[A,F] where not conforms_to(I,ErrorRecovery) and not conforms_to(I, ErrorMapping):
    return pipeline[I](source^).raising[E]().or_else_if(predicate,handler).get()


@fieldwise_init
struct Match(BorrowCallable):
    comptime Payload = String
    comptime Result = Bool
    def invoke(self, value: String) -> Bool: return value == "retry"

@fieldwise_init
struct Length(Unary):
    comptime Arg = String
    comptime Out = Int
    def call(self, var value: String) -> Int: return value.byte_length()

@fieldwise_init
struct Effect(Unary):
    comptime Arg = String
    comptime Out = Result[Int,String]
    def call(self, var value: String) -> Self.Out: return Ok(value.byte_length())


def main() raises:
    comptime I = ResultFamily[String]
    assert_equal(recovered[I](I.fail[Int](String("retry")),Match(),Length())._ok().value,5)
    assert_equal(expanded[I](I.fail[Int](String("retry")),Match(),Length())._ok().value,5)
    assert_equal(replaced[I](I.fail[Int](String("keep")),Match(),Effect())._err().value,"keep")
    assert_equal(expanded_effect[I](I.fail[Int](String("retry")),Match(),Effect())._ok().value,5)
    assert_equal(witnessed[I](I.fail[Int](String("retry")),Match(),Length())._ok().value,5)
    def accept(value: String) raises Never -> Bool: return True
    def length(var value: String) raises Never -> Int: return value.byte_length()
    def effect(var value: String) raises Never -> Result[Int,String]: return Ok(value.byte_length())
    assert_equal(native_recovered(I.fail[Int](String("native")),accept,length)._ok().value,6)
    assert_equal(native_replaced(I.fail[Int](String("native")),accept,effect)._ok().value,6)
    assert_equal(intrinsic_recovered[IdentityFamily](I.fail[Int](String("native")),accept,length)._ok().value,6)
    assert_equal(intrinsic_replaced[IdentityFamily](I.fail[Int](String("native")),accept,effect)._ok().value,6)
    def checked(value: String) raises Int -> Bool: return True
    def raised(var value: String) raises Int -> Int: raise 831
    def raised_effect(var value: String) raises Int -> Result[Int,String]: raise 832
    var code = 0
    try: _ = native_recovered(I.fail[Int](String("x")),checked,raised)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,831)
    try: _ = native_replaced(I.fail[Int](String("x")),checked,raised_effect)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,832)
    def pure_predicate(value: String) -> Bool: return True
    def pure_handler(var value: String) -> Int: return 2
    def failed_predicate(value: String) raises Int -> Bool: raise 833
    try: _ = mixed_handler(I.fail[Int](String("x")),pure_predicate,raised)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,831)
    try: _ = mixed_predicate(I.fail[Int](String("x")),failed_predicate,pure_handler)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,833)
