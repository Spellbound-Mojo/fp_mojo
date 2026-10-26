"""Selected outcome contracts keep family, output and native error forwarding public."""
from fp.algebra import Functor, Applicative, ApplicativeError, Monad, IdentityFamily, ResultFamily
from fp.callables import Unary, UnaryContract
from fp.functions import Pipeline, pipeline, RedeemContract, RedeemWithContract
from fp.data import Result, Ok, Err
from fp.effects import Reader, ReaderT, ResultT, run
from std.testing import assert_equal


def values[I: Functor, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable](var source: V, var on_ok: H, var on_err: K) raises RedeemContract[I,V,H,K].Error -> Pipeline[RedeemContract[I,V,H,K].Family,RedeemContract[I,V,H,K].Out] where RedeemContract[I,V,H,K].Compatible:
    return pipeline[I](source^).redeem(on_ok^,on_err^)


def effects[I: Functor, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable](var source: V, var on_ok: H, var on_err: K) raises RedeemWithContract[I,V,H,K].Error -> Pipeline[RedeemWithContract[I,V,H,K].Family,RedeemWithContract[I,V,H,K].Out] where RedeemWithContract[I,V,H,K].Compatible:
    return pipeline[I](source^).redeem_with(on_ok^,on_err^)


def native_values[A: Movable & Deinitable, F: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, H: def(var A) raises E -> R, K: def(var F) raises E -> R](var source: Result[A,F], on_ok: H, on_err: K) raises E -> Result[R,F]:
    return pipeline(source^).raising[E]().redeem(on_ok,on_err).get()


def native_effects[A: Movable & Deinitable, F: Movable & Deinitable, R: Movable & Deinitable, G: Movable & Deinitable, E: Movable & Deinitable, //, H: def(var A) raises E -> Result[R,G], K: def(var F) raises E -> Result[R,G]](var source: Result[A,F], on_ok: H, on_err: K) raises E -> Result[R,G]:
    return pipeline(source^).raising[E]().redeem_with(on_ok,on_err).get()


def intrinsic_values[A: Movable & Deinitable, F: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Functor, H: def(var A) raises E -> R, K: def(var F) raises E -> R](var source: Result[A,F], on_ok: H, on_err: K) raises E -> Result[R,F] where not conforms_to(I,ApplicativeError):
    return pipeline[I](source^).raising[E]().redeem(on_ok,on_err).get()


def intrinsic_effects[A: Movable & Deinitable, F: Movable & Deinitable, R: Movable & Deinitable, G: Movable & Deinitable, E: Movable & Deinitable, //, I: Functor, H: def(var A) raises E -> Result[R,G], K: def(var F) raises E -> Result[R,G]](var source: Result[A,F], on_ok: H, on_err: K) raises E -> Result[R,G] where not conforms_to(I,ApplicativeError):
    return pipeline[I](source^).raising[E]().redeem_with(on_ok,on_err).get()


@fieldwise_init
struct Show(Unary):
    comptime Arg = Int
    comptime Out = String
    def call(self, var value: Int) -> String: return String(value)

@fieldwise_init
struct Explain(Unary):
    comptime Arg = String
    comptime Out = String
    def call(self, var error: String) -> String: return error^

@fieldwise_init
struct Changed[A: Movable & Deinitable](Unary):
    comptime Arg = Self.A
    comptime Out = Result[String,Int]
    def call(self, var value: Self.A) -> Self.Out: return Err(7)


def expanded[I:Functor,V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable,K:UnaryContract & Movable & Deinitable](var v:V,var h:H,var k:K) raises RedeemContract[I,V,H,K].Error ->Pipeline[RedeemContract[I,V,H,K].Family,RedeemContract[I,V,H,K].Out] where RedeemContract[I,V,H,K].InputCompatible and RedeemContract[I,V,H,K].CarrierCompatible and RedeemContract[I,V,H,K].OutputCompatible and RedeemContract[I,V,H,K].NativeErrorsCompatible and RedeemContract[I,V,H,K].OperationCompatible:
    return values[I](v^,h^,k^)

def expanded_effects[I:Functor,V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable,K:UnaryContract & Movable & Deinitable](var v:V,var h:H,var k:K) raises RedeemWithContract[I,V,H,K].Error ->Pipeline[RedeemWithContract[I,V,H,K].Family,RedeemWithContract[I,V,H,K].Out] where RedeemWithContract[I,V,H,K].InputCompatible and RedeemWithContract[I,V,H,K].CarrierCompatible and RedeemWithContract[I,V,H,K].OutputCompatible and RedeemWithContract[I,V,H,K].NativeErrorsCompatible and RedeemWithContract[I,V,H,K].OperationCompatible:
    return effects[I](v^,h^,k^)

def witness[I:Functor,V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable,K:UnaryContract & Movable & Deinitable](var v:V,var h:H,var k:K) raises RedeemContract[I,V,H,K].Error ->Pipeline[RedeemContract[I,V,H,K].Family,RedeemContract[I,V,H,K].Out] where conforms_to(I,ApplicativeError) and RedeemContract[I,V,H,K].Compatible:
    return expanded[I](v^,h^,k^)

def witness_effect[I:Functor,V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable,K:UnaryContract & Movable & Deinitable](var v:V,var h:H,var k:K) raises RedeemWithContract[I,V,H,K].Error ->Pipeline[RedeemWithContract[I,V,H,K].Family,RedeemWithContract[I,V,H,K].Out] where conforms_to(I,ApplicativeError) and conforms_to(I,Monad) and RedeemWithContract[I,V,H,K].Compatible:
    return expanded_effects[I](v^,h^,k^)

def mixed[A:Movable & Deinitable,E:Movable & Deinitable,R:Movable & Deinitable,X:Movable & Deinitable,//,H:def(var A)->R,K:def(var E) raises X ->R](var v:Result[A,E],h:H,k:K) raises X ->Result[R,E]:
    return pipeline(v^).raising[X]().redeem(h,k).get()

def mixed_intrinsic[A:Movable & Deinitable,E:Movable & Deinitable,R:Movable & Deinitable,X:Movable & Deinitable,//,I:Functor,H:def(var A) raises X ->R,K:def(var E)->R](var v:Result[A,E],h:H,k:K) raises X ->Result[R,E] where not conforms_to(I,ApplicativeError):
    return pipeline[I](v^).raising[X]().redeem(h,k).get()

def mixed_effect[A:Movable & Deinitable,E:Movable & Deinitable,R:Movable & Deinitable,G:Movable & Deinitable,X:Movable & Deinitable,//,H:def(var A)->Result[R,G],K:def(var E) raises X ->Result[R,G]](var v:Result[A,E],h:H,k:K) raises X ->Result[R,G]:
    return pipeline(v^).raising[X]().redeem_with(h,k).get()

@fieldwise_init
struct Keep[I:ApplicativeError,A:Movable & Deinitable](Unary):
    comptime Arg=Self.A
    comptime Out=Self.I.Pure[Int]
    def call(self,var a:Self.A)->Self.Out:return Self.I.pure(7)


def main() raises:
    comptime I = ResultFamily[String]
    var selected = values[I](I.pure(3),Show(),Explain())
    comptime assert type_of(selected).I == I
    assert_equal(selected^.get()._ok().value,"3")
    var changed = effects[I](I.pure(3),Changed[Int](),Changed[String]())
    comptime assert type_of(changed).I == ResultFamily[Int]
    assert_equal(changed^.get()._err().value,7)
    assert_equal(values[IdentityFamily](I.fail[Int](String("old")),Show(),Explain()).get()._ok().value,"old")
    def show(var value: Int) raises Never -> String: return String(value)
    def explain(var error: String) raises Never -> String: return error^
    def next_ok(var value: Int) raises Never -> Result[String,Int]: return Ok(String(value))
    def next_err(var error: String) raises Never -> Result[String,Int]: return Err(error.byte_length())
    assert_equal(native_values(I.pure(4),show,explain)._ok().value,"4")
    assert_equal(native_effects(I.fail[Int](String("four")),next_ok,next_err)._err().value,4)
    assert_equal(intrinsic_values[IdentityFamily](I.pure(5),show,explain)._ok().value,"5")
    assert_equal(intrinsic_effects[IdentityFamily](I.fail[Int](String("five")),next_ok,next_err)._err().value,4)
    def raised(var value: Int) raises Int -> String: raise value
    def unreachable(var error: String) raises Int -> String: raise 999
    var code = 0
    try: _ = native_values(I.pure(91),raised,unreachable)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,91)
    comptime R = Reader[Int]
    comptime D = ResultT[R,String]
    var deferred = values[D](D.fail[Int](String("later")),Show(),Explain()).get()
    assert_equal(run[R](deferred^,0)._ok().value,"later")

    comptime W = ReaderT[I,Int]
    assert_equal(run[W](witness[W](W.fail[Int](String("err")),Show(),Explain()).get(),0)._ok().value,"err")
    assert_equal(run[W](witness_effect[W](W.pure(1),Keep[W,Int](),Keep[W,String]()).get(),0)._ok().value,7)
    def pure_ok(var value: Int) -> String: return String(value)
    def pure_err(var error: String) -> String: return error^
    def raised_err(var error: String) raises Int -> String: raise error.byte_length()
    try: _ = mixed(I.fail[Int](String("three")),pure_ok,raised_err)
    except error: code = error
    assert_equal(code,5)
    try: _ = mixed_intrinsic[IdentityFamily](I.pure(93),raised,pure_err)
    except error: code = error
    assert_equal(code,93)
    def pure_next(var value: Int) -> Result[String,Int]: return Ok(String(value))
    def raised_next(var error: String) raises Int -> Result[String,Int]: return Err(error.byte_length())
    var next: Result[String,Int]
    try: next = mixed_effect(I.fail[Int](String("next")),pure_next,raised_next)
    except _: raise Error("unexpected native error")
    assert_equal(next._err().value,4)
    assert_equal(pipeline(I.pure(8)).redeem(Show(),pure_err).get()._ok().value,"8")
    assert_equal(pipeline(I.fail[Int](String("mixed"))).redeem(pure_ok,Explain()).get()._ok().value,"mixed")
    def pure_next_err(var error: String) -> Result[String,Int]: return Err(error.byte_length())
    assert_equal(pipeline(I.pure(8)).redeem_with(Changed[Int](),pure_next_err).get()._err().value,7)
