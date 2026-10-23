"""Generic callbacks retain payload origins and exact native errors."""
from fp.data import Result, Ok
from fp.functions import piped
from fp.callables import UnaryContract, Unary, as_unary
from std.testing import assert_equal


def fcg_combine[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
                E: Movable & Deinitable, X: Movable & Deinitable,
                F: def(var A, var B) raises X -> R](var left: Result[A, E], var right: Result[B, E], ref function: F
) raises X -> Result[R, E]:
    return left^.map2[X=X](right^, function)


def fcg_piped[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
              E: Movable & Deinitable, X: Movable & Deinitable,
              F: def(var A, var B) raises X -> R](var left: Result[A, E], var right: Result[B, E], ref function: F
) raises X -> Result[R, E]:
    return piped(left^).map2[A=A, B=B, R=R, X=X](right^, function).get()


def fcg_add(a: Int, b: Int) raises String -> Int: return a + b


def fcg_apply[F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](
    var function: Result[F, E], var values: Result[F.Arg, E]
) raises F.Error -> Result[F.Out, E]:
    return function^.ap(values^)


def fcg_apply_piped[F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](
    var function: Result[F, E], var values: Result[F.Arg, E]
) raises F.Error -> Result[F.Out, E]:
    return piped(function^).ap(values^).get()


def fcg_twice(value: Int) raises String -> Int: return value * 2


@fieldwise_init
struct FCGView[o: ImmOrigin](Unary):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Span[Int, Self.o]
    def call(self, var arg: Self.Arg) -> Self.Out: return arg


def fcg_views(values: List[Int]) raises:
    var view = Span(values)
    var result = Result[type_of(view), String](Ok(view)).product(Result[Int, String](Ok(3)))
    var pair = result^.raise_on_err()
    comptime assert type_of(pair) == Tuple[type_of(view), Int]
    assert_equal(pair[0][0] + pair[1], 10)
    var function = Result[FCGView[origin_of(values)], String](Ok(FCGView[origin_of(values)]()))
    var applied = fcg_apply_piped(function^, Result[type_of(view), String](Ok(view))).raise_on_err()
    assert_equal(applied[1], 8)



def fcg_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable,
              R: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable,
              F: def(var A0, var A1, var A2) raises X -> R](
    var first: Result[A0,E], var others: Tuple[Result[A1,E],Result[A2,E]], ref function: F
) raises X -> Result[R,E]:
    return first^.map_n[A0=A0,A1=A1,A2=A2,R=R,X=X](others^,function)


def fcg_map_n_piped[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable,
              R: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable,
              F: def(var A0, var A1, var A2) raises X -> R](
    var first: Result[A0,E], var others: Tuple[Result[A1,E],Result[A2,E]], ref function: F
) raises X -> Result[R,E]:
    return piped(first^).map_n[A0=A0,A1=A1,A2=A2,R=R,X=X](others^,function).get()


def fcg_sum_three(a:Int,b:Int,c:Int) raises String -> Int: return a+b+c


@fieldwise_init
struct FCGTupleView[o: ImmOrigin](Unary):
    comptime Arg=Tuple[Span[Int,Self.o],Int]
    comptime Out=Span[Int,Self.o]
    def call(self,var arg:Self.Arg) -> Self.Out: return arg[0]


def fcg_library_view[o: ImmOrigin](var first:Result[Span[Int,o],String],var second:Result[Int,String]) -> Result[Span[Int,o],String]:
    return first^.map_n((second^,),FCGTupleView[o]())


def fcg_nary_views(values: List[Int]) raises:
    var view=Span(values)
    comptime View=type_of(view)
    def keep(var a:View,b:Int,c:Int) raises String -> View: return a
    var tupled=piped(Result[type_of(view),String](Ok(view))).product_n((Result[Int,String](Ok(2)),Result[type_of(view),String](Ok(view)))).get().raise_on_err()
    comptime assert type_of(tupled) == Tuple[type_of(view),Int,type_of(view)]
    assert_equal(tupled[0][0]+tupled[1]+tupled[2][1],17)
    var mapped = fcg_map_n(Result[type_of(view),String](Ok(view)),(Result[Int,String](Ok(1)),Result[Int,String](Ok(2))),keep).raise_on_err()
    comptime assert type_of(mapped) == type_of(view)
    assert_equal(mapped[1],8)
    var library = fcg_library_view(Result[type_of(view),String](Ok(view)),Result[Int,String](Ok(1))).raise_on_err()
    assert_equal(library[1],8)
    def fail(var a:View,b:Int,c:Int) raises View -> Int:
        raise a
    var observed = 0
    try:
        _=piped(Optional(view)).map_n((Optional(2),Optional(3)),fail).get()
    except error:
        comptime assert type_of(error) == type_of(view)
        observed = error[1]
    assert_equal(observed,8)


def fcg_nary() raises:
    var got=0
    try:
        var a=fcg_map_n(Result[Int,String](Ok(1)),(Result[Int,String](Ok(2)),Result[Int,String](Ok(3))),fcg_sum_three)
        got=fcg_map_n_piped(a^,(Result[Int,String](Ok(4)),Result[Int,String](Ok(5))),fcg_sum_three).raise_on_err()
    except: pass
    assert_equal(got,15)
    fcg_nary_views([7,8])

def main() raises:
    fcg_nary()
    var actual: Int
    try:
        var a = fcg_combine(Result[Int, String](Ok(3)), Result[Int, String](Ok(4)), fcg_add)
        var b = fcg_piped(a^, Result[Int, String](Ok(5)), fcg_add)
        actual = b^.raise_on_err()
    except error:
        actual = -1
    assert_equal(actual, 12)
    fcg_views([7, 8])
    var native = as_unary(fcg_twice)
    var answer = 0
    try:
        var first = fcg_apply(Result[type_of(native), String](Ok(native.copy())), Result[Int, String](Ok(3)))
        answer = fcg_apply_piped(Result[type_of(native), String](Ok(native^)), first^).raise_on_err()
    except: pass
    assert_equal(answer, 12)
