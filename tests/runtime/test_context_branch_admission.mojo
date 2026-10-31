"""Branch contracts reject consuming receivers before invoking family bodies."""
from fp.algebra import ApplicativeError, Functor, Monad, ListFamily, ResultFamily, map, flat_map
from fp.algebra.contracts import MapContract, BindContract, RecoverContract, TapErrContract
from fp.callables import UnaryContract, RepeatableUnary
from fp.data import Result,Err,Ok
from fp.effects import OptionalT,ResultT,StateT,Reader,action,run
from fp.functions import pipeline, OrElseContract
from context_branch_admission_support import OnceMap,StatefulMap,OnceNext,Next,OnceRecovery,OnceValue,Value,OnceObserver,MoveState,FailedBranches,TakeState,AdmissionBase
from std.testing import assert_equal
from std.builtin.rebind import downcast


def mapped[I:Functor,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var value:V,var f:F) raises MapContract[I,V,F].Error -> MapContract[I,V,F].Out where MapContract[I,V,F].Compatible:
    return pipeline[I](value^).map(f^).get()

def bound[I:Monad,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var value:V,var f:F) raises BindContract[I,V,F].Error -> BindContract[I,V,F].Out where BindContract[I,V,F].Compatible:
    return pipeline[I](value^).flat_map(f^).get()


def list_mapped[I:Functor,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var values:V,var f:F) raises MapContract[I,V,F].Error -> MapContract[I,V,F].Out where MapContract[I,V,F].Compatible:
    return map[I](values^, f^)


def metadata():
    comptime L=ListFamily
    comptime O=OptionalT[L]
    comptime R=ResultT[L,String]
    comptime Nested=downcast[OptionalT[R],ApplicativeError]
    comptime assert not MapContract[L,List[Int],OnceMap].Compatible
    comptime assert not BindContract[L,List[Int],OnceNext[L]].Compatible
    comptime assert not MapContract[O,O.Pure[Int],OnceMap].Compatible
    comptime assert not BindContract[O,O.Pure[Int],OnceNext[O]].Compatible
    comptime assert not MapContract[R,R.Pure[Int],OnceMap].Compatible
    comptime assert not BindContract[R,R.Pure[Int],OnceNext[R]].Compatible
    comptime assert not OrElseContract[R,R.Pure[Int],OnceRecovery[R]].Compatible
    comptime assert not RecoverContract[R,R.Pure[Int],OnceValue].Compatible
    comptime assert not TapErrContract[R,R.Pure[Int],OnceObserver].Compatible
    comptime assert not RecoverContract[Nested,Nested.Pure[Int],OnceValue].Compatible
    comptime S=StateT[R,MoveState]
    var action_value=action[S,Int](FailedBranches())
    comptime assert not TapErrContract[S,type_of(action_value),OnceObserver].Compatible
    _=action_value^
    comptime assert MapContract[L,List[MoveState],TakeState].Compatible
    comptime assert MapContract[L,List[Int],StatefulMap].Compatible
    comptime assert MapContract[O,O.Pure[Int],StatefulMap].Compatible
    comptime assert BindContract[R,R.Pure[Int],Next[R]].Compatible
    comptime assert RecoverContract[R,R.Pure[Int],Value].Compatible


def repeated() raises:
    comptime O=OptionalT[ListFamily]
    comptime R=ResultT[ListFamily,String]
    assert_equal(mapped[ListFamily](List[Int]([10,20]),StatefulMap(0)),[11,22])
    assert_equal(list_mapped[ListFamily](List[Int]([10,20]),StatefulMap(0)),[11,22])
    var owners:List[MoveState]=[MoveState(10),MoveState(20)]
    assert_equal(mapped[ListFamily](owners^,TakeState(0)),[11,22])
    var optional=mapped[O](List[Optional[Int]]([Optional(10),Optional[Int](),Optional(20)]),StatefulMap(0))
    assert_equal(optional[0].value(),11)
    assert_equal(Bool(optional[1]),False)
    assert_equal(optional[2].value(),22)
    var source=List[Result[Int,String]]([Result[Int,String](Ok(10)),Result[Int,String](Err(String("skip"))),Result[Int,String](Ok(20))])
    var result=mapped[R](source^,StatefulMap(0))
    assert_equal(result[0]._ok().value,11)
    assert_equal(result[1]._err().value,"skip")
    assert_equal(result[2]._ok().value,22)
    assert_equal(bound[ListFamily](List[Int]([1,2]),Next[ListFamily]()),[2,3])
    var chained=bound[R](R.pure(4),Next[R]())
    assert_equal(chained[0]._ok().value,5)
    var errors=List[Result[Int,String]]([Result[Int,String](Err(String("one"))),Result[Int,String](Err(String("four")))])
    var recovered=pipeline[R](errors^).recover(Value()).get()
    assert_equal(recovered[0]._ok().value,3)
    assert_equal(recovered[1]._ok().value,4)


def single_execution() raises:
    comptime Base=Reader[Int]
    comptime R=ResultT[Base,String]
    comptime O=OptionalT[Base]
    # Consuming receivers remain valid when the actual base primitive runs once.
    var recovered=pipeline[R](R.fail[Int](String("later"))).recover(OnceValue()).get()
    assert_equal(run[Base](recovered^,0)._ok().value,5)
    var observed=pipeline[R](R.fail[Int](String("kept"))).tap_err(OnceObserver()).get()
    assert_equal(run[Base](observed^,0)._err().value,"kept")
    assert_equal(run[Base](mapped[R](R.pure(3),OnceMap()),0)._ok().value,4)
    assert_equal(run[Base](bound[O](O.pure(4),OnceNext[O]()),0).value(),5)


def independent_admission() raises:
    comptime Base=AdmissionBase[ResultFamily[String],False]
    comptime O=OptionalT[Base]
    comptime R=ResultT[Base,String]
    comptime assert not MapContract[O,O.Pure[Int],StatefulMap].Compatible
    comptime assert not MapContract[R,R.Pure[Int],StatefulMap].Compatible
    comptime assert BindContract[O,O.Pure[Int],Next[O]].Compatible
    comptime assert BindContract[R,R.Pure[Int],Next[R]].Compatible
    comptime assert RecoverContract[R,R.Pure[Int],Value].Compatible
    assert_equal(bound[O](O.pure(3),Next[O]())._ok().value.value(),4)
    assert_equal(bound[R](R.pure(4),Next[R]())._ok().value._ok().value,5)
    var recovered=pipeline[R](R.fail[Int](String("inner"))).recover(Value()).get()
    assert_equal(recovered._ok().value._ok().value,5)


def native_admission() raises:
    def increment(var value:Int)->Int:return value+1
    def branches(var value:Int)->List[Int]:return [value,value+10]
    def raising(var value:Int) raises String -> Int:
        if value<0:raise String("negative")
        return value+2
    assert_equal(map[ListFamily](List[Int]([1,2]),increment),[2,3])
    assert_equal(flat_map[ListFamily](List[Int]([1,2]),branches),[1,11,2,12])
    assert_equal(pipeline(List[Int]([3,4])).map(increment).get(),[4,5])
    assert_equal(pipeline(List[Int]([3,4])).map(StatefulMap(0)).get(),[4,6])
    var raised_map:List[Int]
    try:
        raised_map=pipeline(List[Int]([3,4])).map(raising).get()
    except error:
        comptime assert type_of(error)==String
        raise Error(error)
    assert_equal(raised_map,[5,6])
    comptime O=OptionalT[ListFamily]
    assert_equal(pipeline[O](O.pure(5)).map(increment).get()[0].value(),6)
    comptime R=ResultT[ListFamily,String]
    def next_result(var value:Int)->R.Pure[Int]:return R.pure(value+3)
    assert_equal(flat_map[R](R.pure(6),next_result)[0]._ok().value,9)


def main() raises:
    metadata()
    repeated()
    single_execution()
    independent_admission()
    native_admission()
