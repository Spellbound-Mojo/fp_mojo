"""Selected and intrinsic native observation forwards preserve exact signatures."""
from fp.functions import pipeline
from fp.algebra import Functor, ApplicativeError, ErrorMapping, IdentityFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal


def intrinsic_tap[A: Movable & Deinitable, E: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, o: ImmOrigin, //, I: Functor, F: def(E) raises X -> R](var source: Result[A,E], ref[o] callback: F) raises X -> Result[A,E] where not conforms_to(I, ApplicativeError) and not conforms_to(I, ErrorMapping):
    return pipeline[I](source^).raising[X]().tap_err(callback).get()


def intrinsic_flat[A: Movable & Deinitable, E: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, o: ImmOrigin, //, I: Functor, F: def(E) raises X -> Result[R,E]](var source: Result[A,E], ref[o] callback: F) raises X -> Result[A,E] where not conforms_to(I, ApplicativeError) and not conforms_to(I, ErrorMapping):
    return pipeline[I](source^).raising[X]().flat_tap_err(callback).get()


def thin_tap[A: Movable & Deinitable, E: TrivialRegisterPassable, R: TrivialRegisterPassable, X: Movable & Deinitable](var source: Result[A,E], callback: def(E) raises X thin -> R) raises X -> Result[A,E]:
    return pipeline(source^).raising[X]().tap_err(callback).get()


def thin_flat[A: Movable & Deinitable, E: TrivialRegisterPassable, R: Movable & Deinitable, X: Movable & Deinitable](var source: Result[A,E], callback: def(E) raises X thin -> Result[R,E]) raises X -> Result[A,E]:
    return pipeline(source^).raising[X]().flat_tap_err(callback).get()


def observed(value: Int) raises Never -> Int: return value

def effected(value: Int) raises Never -> Result[String,Int]: return Err(value + 1)

def raised(value: Int) raises Int -> Int: raise value + 2


def origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    def inspect(value: View) -> View: return value
    def effect(value: View) -> Result[NoneType,View]: return Err(value)
    var pointer: def(View) thin -> View = inspect
    var effect_pointer: def(View) thin -> Result[NoneType,View] = effect
    var kept = pipeline(Result[Int,View](Err(view))).tap_err(pointer).get()
    var effected = pipeline(Result[Int,View](Err(view))).flat_tap_err(effect_pointer).get()
    assert_equal(kept._err().value.unsafe_ptr() == Span(owner).unsafe_ptr(), True)
    assert_equal(effected._err().value.unsafe_ptr() == Span(owner).unsafe_ptr(), True)
    def fail(value: View) raises View {view} -> Int: raise view
    var same = False
    try: _ = pipeline(Result[Int,View](Err(view))).raising[View]().tap_err(fail).get()
    except error:
        comptime assert type_of(error) == View
        same = error.unsafe_ptr() == Span(owner).unsafe_ptr()
    assert_equal(same, True)


def generic[A:Movable & Deinitable,E:Movable & Deinitable,R:Movable & Deinitable,X:Movable & Deinitable,o:ImmOrigin,//,F:def(E) raises X -> R](var source:Result[A,E],ref[o] callback:F) raises X -> Result[A,E]:
    return pipeline(source^).raising[X]().tap_err(callback).get()
def generic_flat[A:Movable & Deinitable,E:Movable & Deinitable,R:Movable & Deinitable,X:Movable & Deinitable,o:ImmOrigin,//,F:def(E) raises X -> Result[R,E]](var source:Result[A,E],ref[o] callback:F) raises X -> Result[A,E]:
    return pipeline(source^).raising[X]().flat_tap_err(callback).get()

def main() raises:
    def inspect(error:String) raises Never ->Int:return 0
    def effect(error:String) raises Never ->Result[NoneType,String]:return Err(String("effect"))
    assert_equal(generic(Result[Int,String](Err(String("g"))),inspect)._err().value,"g")
    assert_equal(generic_flat(Result[Int,String](Err(String("g"))),effect)._err().value,"effect")
    assert_equal(intrinsic_tap[IdentityFamily](Result[String,Int](Err(4)), observed)._err().value, 4)
    assert_equal(intrinsic_flat[IdentityFamily](Result[String,Int](Err(4)), effected)._err().value, 5)
    var pointer: def(Int) raises Never thin -> Int = observed
    var effect_pointer: def(Int) raises Never thin -> Result[String,Int] = effected
    var raised_pointer: def(Int) raises Int thin -> Int = raised
    assert_equal(thin_tap(Result[String,Int](Err(4)), pointer)._err().value, 4)
    assert_equal(thin_flat(Result[String,Int](Err(4)), effect_pointer)._err().value, 5)
    var code = 0
    try: _ = thin_tap(Result[String,Int](Err(4)), raised_pointer)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,6)
    origins(List[Int]([3,7]))
