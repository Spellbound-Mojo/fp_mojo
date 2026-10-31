"""Search and mapped reductions preserve Monad timing, failure and branching."""
from fp.iteration import iterated, find_effect, find_map_effect, fold_map_effect, sequence_filter
from fp.functions import piped
from fp.algebra import OptionalFamily, ResultFamily, IdentityFamily, ListFamily, IorFamily, StringMonoid, Monoid
from fp.data import Result, Ok, Err, Ior, Both
from fp.effects import Reader, State, Writer, action, run, writer, run_writer
from fp.callables import Unary, MutableUnary
from std.collections import Array, Deque
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, assert_false
from algebra_support.iterators import Counted
from test_combinators import CombinatorRestarting
from test_algebra_third_party import Cell, CellFamily


def i6_predicate(value:Int)->Result[Bool,String]: return Ok(value==2)
def i6_project(var value:Int)->Result[Optional[String],String]:
    if value==2:return Ok(Optional(String(value)))
    return Ok(Optional[String]())
def i6_text(var value:Int)->Result[String,String]: return Ok(String(value))
def i6_cell(var value:Int)->Cell[Optional[Int]]: return Cell(Optional(value))
def i6_logged(var value:Int)->Writer[StringMonoid].Pure[String]:
    return writer[Writer[StringMonoid],String](("log"+String(value),String(value)))
def i6_warn(var value:Int)->Ior[String,String]: return Both(String("w"),String(value))


@fieldwise_init
struct I6Mapper(MutableUnary):
    comptime Arg=Int
    comptime Out=Optional[Optional[Int]]
    var calls:Int
    def call_mut(mut self,var value:Int)->Self.Out:
        self.calls+=1
        if self.calls==2:return Optional(Optional(value))
        return Optional(Optional[Int]())


def basic() raises:
    assert_equal(find_effect[ResultFamily[String]](range(5),i6_predicate).raise_on_err().value(),2)
    assert_equal(iterated(range(5)).find_map_effect[ResultFamily[String]](i6_project).raise_on_err().value(),"2")
    assert_false(find_effect[ResultFamily[String]](range(0),i6_predicate).raise_on_err())
    assert_false(find_map_effect[ResultFamily[String]](range(1),i6_project).raise_on_err())
    assert_equal(iterated(range(4)).fold_map_effect[ResultFamily[String],StringMonoid](i6_text).raise_on_err(),"0123")
    assert_equal(fold_map_effect[StringMonoid, ResultFamily[String]](range(0),i6_text).raise_on_err(),"")
    var xs:List[Int]=[0,1,2]
    assert_equal(piped(xs^).find_effect[ResultFamily[String]](i6_predicate).get().raise_on_err().value(),2)
    var array:Array[Int,3]=[0,1,2]
    assert_equal(piped(array^).find_map_effect[ResultFamily[String]](i6_project).get().raise_on_err().value(),"2")
    var array2:Array[Int,3]=[0,1,2]
    assert_equal(piped(array2^).fold_map_effect[StringMonoid, ResultFamily[String]](i6_text).get().raise_on_err(),"012")
    assert_equal(iterated(range(5)).find_map_effect[OptionalFamily](I6Mapper(0)).value().value(),1)
    assert_equal(find_map_effect[CellFamily](range(3),i6_cell).value.value(),0)
    assert_equal(run_writer[Writer[StringMonoid]](fold_map_effect[StringMonoid, Writer[StringMonoid]](range(3),i6_logged)),(String("log0log1log2"),String("012")))
    var warnings=fold_map_effect[StringMonoid, IorFamily[StringMonoid]](range(3),i6_warn)
    assert_equal(warnings[Both[String,String]].left,"www")
    assert_equal(warnings[Both[String,String]].right,"012")
    var cursor=CombinatorRestarting(1)
    _=cursor.__next__()
    assert_equal(iterated(cursor^).find_effect[ResultFamily[String]](i6_predicate).raise_on_err().value(),2)


def stopping() raises:
    var calls=ArcPointer(0)
    var pulls=0
    def choose(value:Int) {calls}->Optional[Bool]:
        calls[]+=1
        return Optional(value==2)
    assert_equal(iterated(Counted(Pointer(to=pulls),0,8)).find_effect[OptionalFamily](choose).value().value(),2)
    assert_equal(calls[],2);assert_equal(pulls,2)
    calls[]=0;pulls=0
    def missing(var value:Int) {calls}->Result[Optional[Int],String]:
        calls[]+=1
        if value==2:return Err(String("stored"))
        return Ok(Optional[Int]())
    assert_true(find_map_effect[ResultFamily[String]](Counted(Pointer(to=pulls),0,8),missing).is_err())
    assert_equal(calls[],2);assert_equal(pulls,2)
    calls[]=0;pulls=0
    def absent(value:Int) {calls}->Optional[Bool]:
        calls[]+=1
        return None
    assert_false(find_effect[OptionalFamily](Counted(Pointer(to=pulls),0,8),absent))
    assert_equal(calls[],1);assert_equal(pulls,1)
    calls[]=0;pulls=0
    def branching(var value:Int) {calls}->List[Optional[Int]]:
        calls[]+=1
        if value==1:return [Optional[Int](),Optional(value)]
        return [Optional(20)]
    var found=find_map_effect[ListFamily](Counted(Pointer(to=pulls),0,8),branching)
    assert_equal(len(found),2)
    assert_equal(found[0].value(),20);assert_equal(found[1].value(),1)
    assert_equal(calls[],2);assert_equal(pulls,2)
    calls[]=0
    def alternatives(var value:Int) {calls}->List[String]:
        calls[]+=1
        if value==0:return ["a","A"]
        return ["b","B"]
    assert_equal(fold_map_effect[StringMonoid, ListFamily](range(2),alternatives),["ab","aB","Ab","AB"])
    assert_equal(calls[],3)


@fieldwise_init
struct I6StatePredicate(Unary):
    comptime Arg=Int
    comptime Out=Tuple[Bool,Int]
    var value:Int
    def call(self,var state:Int)->Self.Out: return (self.value==2,state+1)

def i6_state_predicate(value:Int)->State[Int].Endpoint[Bool,I6StatePredicate]:
    return action[State[Int],Bool](I6StatePredicate(value))


def deferred() raises:
    var calls=ArcPointer(0)
    var pulls=0
    def select(var value:Int) {calls}->Reader[Int].Pure[Optional[Int]]:
        calls[]+=1
        return Reader[Int].pure(Optional(value) if value==2 else Optional[Int]())
    var search=find_map_effect[Reader[Int]](Counted(Pointer(to=pulls),0,8),select)
    assert_equal(calls[],0);assert_equal(pulls,0)
    assert_equal(run[Reader[Int]](search^,10).value(),2)
    assert_equal(calls[],2);assert_equal(pulls,2)
    pulls=0
    var selected=iterated(Counted(Pointer(to=pulls),0,8)).find_effect[State[Int]](i6_state_predicate)
    assert_equal(pulls,0)
    var state_result=run[State[Int]](selected^,10)
    assert_equal(state_result[0].value(),2);assert_equal(state_result[1],12)
    assert_equal(pulls,2)
    calls[]=0;pulls=0
    def text(var value:Int) {calls}->Reader[Int].Pure[String]:
        calls[]+=1
        return Reader[Int].pure(String(value))
    var total=fold_map_effect[StringMonoid, Reader[Int]](Counted(Pointer(to=pulls),0,3),text)
    assert_equal(calls[],0);assert_equal(pulls,0)
    assert_equal(run[Reader[Int]](total^,0),"123")
    assert_equal(calls[],3);assert_equal(pulls,4)


@fieldwise_init
struct I6Failure(Movable):
    var code:Int

struct I6Monoid[fail_start:Bool](Monoid):
    comptime Value=String
    comptime Error=I6Failure
    @staticmethod
    def empty() raises Self.Error -> String:
        if Self.fail_start:raise I6Failure(10)
        return String()
    @staticmethod
    def combine(var a:String,var b:String) raises Self.Error -> String:
        if b=="2":raise I6Failure(20)
        a += b
        return a^


def errors() raises:
    var calls=ArcPointer(0)
    var pulls=0
    def text(var value:Int) {calls}->Optional[String]:
        calls[]+=1
        return Optional(String(value))
    var code=0
    try: _=fold_map_effect[I6Monoid[True], OptionalFamily](Counted(Pointer(to=pulls),0,5),text)
    except error:
        comptime assert type_of(error)==I6Failure
        code=error.code
    assert_equal(code,10);assert_equal(calls[],0);assert_equal(pulls,0)
    try: _=fold_map_effect[I6Monoid[False], OptionalFamily](Counted(Pointer(to=pulls),0,5),text)
    except error:
        comptime assert type_of(error)==I6Failure
        code=error.code
    assert_equal(code,20);assert_equal(calls[],2);assert_equal(pulls,2)
    pulls=0
    def failure(var value:Int) raises I6Failure -> Optional[Optional[Int]]:
        raise I6Failure(value)
    try: _=find_map_effect[OptionalFamily](Counted(Pointer(to=pulls),0,5),failure)
    except error:code=error.code
    assert_equal(code,1);assert_equal(pulls,1)
    from std.iter import StopIteration
    def native_stop(value:Int) raises StopIteration -> Optional[Bool]:raise StopIteration()
    var stopped=False
    try: _=find_effect[OptionalFamily](range(4),native_stop)
    except StopIteration:stopped=True
    assert_true(stopped)


def deferred_errors() raises:
    var calls=ArcPointer(0)
    var pulls=0
    def failure(var value:Int) raises I6Failure {calls} -> Reader[Int].Pure[Optional[Int]]:
        calls[]+=1
        raise I6Failure(value)
    var search=find_map_effect[Reader[Int]](Counted(Pointer(to=pulls),0,5),failure)
    assert_equal(calls[],0);assert_equal(pulls,0)
    var code=0
    try: _=run[Reader[Int]](search^,0)
    except error:
        comptime assert type_of(error)==I6Failure
        code=error.code
    assert_equal(code,1);assert_equal(calls[],1);assert_equal(pulls,1)
    calls[]=0;pulls=0
    def text(var value:Int) {calls}->Reader[Int].Pure[String]:
        calls[]+=1
        return Reader[Int].pure(String(value))
    try: _=fold_map_effect[I6Monoid[True], Reader[Int]](Counted(Pointer(to=pulls),0,5),text)
    except error: code=error.code
    assert_equal(code,10);assert_equal(calls[],0);assert_equal(pulls,0)
    # Construction may raise only the identity error. Combination is deferred.
    try:
        var folded=fold_map_effect[I6Monoid[False], Reader[Int]](Counted(Pointer(to=pulls),0,5),text)
        if calls[]!=0 or pulls!=0:raise I6Failure(-1)
        _=run[Reader[Int]](folded^,0)
    except error:
        comptime assert type_of(error)==I6Failure
        code=error.code
    assert_equal(code,20);assert_equal(calls[],2);assert_equal(pulls,2)


def sequencing() raises:
    var xs=List[Result[Optional[Int],String]]()
    xs.append(Ok(Optional(1)));xs.append(Ok(Optional[Int]()));xs.append(Ok(Optional(3)))
    assert_equal(sequence_filter[ResultFamily[String]](xs.copy()).raise_on_err(),[1,3])
    assert_equal(iterated(xs.copy()).sequence_filter[ResultFamily[String]]().raise_on_err(),[1,3])
    assert_equal(piped(xs^).sequence_filter[G=ResultFamily[String]]().get().raise_on_err(),[1,3])
    var bad=List[Result[Optional[Int],String]]()
    bad.append(Err(String("stored")));bad.append(Ok(Optional(3)))
    assert_true(sequence_filter[ResultFamily[String]](bad^).is_err())
    var single=Optional(Optional(Optional(4)))
    var value=piped(single^).sequence_filter[G=OptionalFamily]().get()
    assert_equal(value.value().value(),4)
    assert_equal(sequence_filter[ResultFamily[String]](List[Result[Optional[Int],String]]()).raise_on_err(),List[Int]())


def main() raises:
    basic()
    stopping()
    deferred()
    errors()
    sequencing()
    deferred_errors()
