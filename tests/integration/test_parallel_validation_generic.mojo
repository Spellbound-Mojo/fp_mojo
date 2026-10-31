"""Imported generic admission keeps native callbacks and embedded origins exact."""
from fp.algebra import Semigroup, ListMonoid, ValidationFamily, ListFamily, traverse
from fp.callables import Unary, UnaryContract, NativeUnary
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from fp.iteration import iterated
from std.testing import assert_equal


def pvg_native[A:Movable & Deinitable,B:Movable & Deinitable,R:Movable & Deinitable,
               E:Movable & Deinitable,X:Movable & Deinitable,
               F:def(var A,var B) raises X -> R](var left:Result[A,List[E]],var right:Result[B,List[E]],ref function:F
) raises X -> Result[R,List[E]]:
    return pipeline(left^).raising[X]().par_map_n((right^,),function).get()


def pvg_piped[A:Movable & Deinitable,B:Movable & Deinitable,R:Movable & Deinitable,
               E:Movable & Deinitable,X:Movable & Deinitable,
               F:def(var A,var B) raises X -> R](var left:Result[A,List[E]],var right:Result[B,List[E]],ref function:F
) raises X -> Result[R,List[E]]:
    return pipeline(left^).raising[X]().par_map_n((right^,),function).get()


def pvg_traverse[A:Movable & Deinitable,R:Movable & Deinitable,E:Movable & Deinitable,
                 F:def(var A) raises E -> R, //, S:Semigroup](var values:List[A],var function:F
) raises ValidationFamily[S].CollectError[List[A],NativeUnary[A,R,E,F,True]] -> ValidationFamily[S].Collected[List[A],NativeUnary[A,R,E,F,True]] where S.Error == Never and R == ValidationFamily[S].Pure[ValidationFamily[S].Element[R]]:
    return pipeline(values^).par_traverse[S](NativeUnary[A,R,E,F,True](function^)).get()


@fieldwise_init
struct PVGKeep[o:ImmOrigin](Unary, Copyable, Defaultable):
    comptime Arg=Tuple[Span[Int,Self.o],Int]
    comptime Out=Span[Int,Self.o]
    def call(self,var arg:Self.Arg) -> Self.Out: return arg[0]


def pvg_product[A:Movable & Deinitable,B:Movable & Deinitable,E:Movable & Deinitable](
    var left:Result[A,List[E]],var right:Result[B,List[E]]
) -> Result[Tuple[A,B],List[E]]:
    return pipeline(left^).par_product_n((right^,)).get()


def pvg_product_policy[A:Movable & Deinitable,B:Movable & Deinitable,//,S:Semigroup](
    var left:Result[A,S.Value],var right:Result[B,S.Value]
) raises S.Error -> Result[Tuple[A,B],S.Value]:
    return pipeline(left^).par_product_n[S]((right^,)).get()


def pvg_sequence[A:Movable & Deinitable,E:Movable & Deinitable](
    var values:List[Result[A,List[E]]]
) -> Result[List[A],List[E]]:
    return pipeline(values^).par_sequence().get()


def pvg_sequence_policy[A:Movable & Deinitable,//,S:Semigroup](
    var values:List[Result[A,S.Value]]
) raises S.Error -> Result[List[A],S.Value]:
    return iterated(values^).par_sequence[S]()


def pvg_origins(values:List[Int]) raises:
    var view=Span(values)
    comptime View=type_of(view)
    def keep(var a:View,b:Int) raises String -> View: return a
    var combined=pvg_native(Result[View,List[String]](Ok(view)),Result[Int,List[String]](Ok(1)),keep)
    comptime assert type_of(combined)==Result[View,List[String]]
    assert_equal(combined._ok().value[1],8)
    var piped_result=pvg_piped(Result[View,List[String]](Ok(view)),Result[Int,List[String]](Ok(1)),keep)
    assert_equal(piped_result._ok().value[0],7)
    var owned=pipeline(Result[View,List[String]](Ok(view))).par_map_n((Result[Int,List[String]](Ok(2)),),PVGKeep[origin_of(values)]()).get()
    assert_equal(owned._ok().value[1],8)
    # Error origins also survive list concatenation, without copying payloads.
    var first:List[View]=[view]
    var second:List[View]=[view]
    def add(a:Int,b:Int)->Int: return a+b
    var failures=pipeline(Result[Int,List[View]](Err(first^))).par_map_n((Result[Int,List[View]](Err(second^)),),add).get()
    comptime assert type_of(failures)==Result[Int,List[View]]
    assert_equal(failures._err().value[1][0],7)
    var product = pvg_product(Result[View,List[String]](Ok(view)),Result[Int,List[String]](Ok(2)))
    comptime assert type_of(product) == Result[Tuple[View,Int],List[String]]
    assert_equal(product._ok().value[0][1],8)
    var explicit_product = pvg_product_policy[ListMonoid[String]](Result[View,List[String]](Ok(view)),Result[Int,List[String]](Ok(3)))
    assert_equal(explicit_product._ok().value[0][0],7)
    comptime R = Result[View,List[View]]
    var views:List[R] = [R(Ok(view))]
    var sequenced = pvg_sequence(views^)
    comptime assert type_of(sequenced) == Result[List[View],List[View]]
    assert_equal(sequenced._ok().value[0][1],8)
    var errors:List[R] = [R(Err(List[View]([view]))),R(Err(List[View]([view])))]
    var error_sequence = pvg_sequence_policy[ListMonoid[View]](errors^)
    comptime assert type_of(error_sequence) == Result[List[View],List[View]]
    assert_equal(error_sequence._err().value[1][0],7)


def pvg_check(value:Int) raises String -> Result[Int,List[String]]:
    if value<0:
        var errors:List[String]=[String(value)]
        return Err(errors^)
    return Ok(value*2)


def main() raises:
    pvg_origins([7,8])
    var gathered:Result[List[Int],List[String]]
    try:
        gathered=pvg_traverse[ListMonoid[String]](List[Int]([1,-2,-3]),pvg_check)
    except error:
        comptime assert type_of(error)==String
        raise Error(error^)
    assert_equal(gathered._err().value,[String('-2'),String('-3')])
    print('parallel validation generic: ok')
