"""Effectful folds, predicates, and selected factories share effect sequencing."""
from fp.functions import piped
from fp.iteration import iterated
from fp.combinators import fold_effect, any_effect, all_effect, if_effect
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, IdentityFamily, StringMonoid
from fp.data import Result, Ok, Err
from fp.callables import Binary, BorrowCallable, Unary, MutableThunk
from fp.effects import Reader, State, Writer, action, run, writer, run_writer
from std.memory import ArcPointer
from std.collections import Array, Deque, LinkedList
from std.testing import assert_equal, assert_true, assert_false
from algebra_support.iterators import Counted
from test_combinators import CombinatorRestarting
from test_algebra_third_party import Cell, CellFamily


def ef_add(a: Int, b: Int) -> Result[Int, String]: return Ok(a+b)
def ef_positive(x: Int) -> Result[Bool, String]: return Ok(x>0)
def ef_yes() -> Result[Int, String]: return Ok(11)
def ef_no() -> Result[Int, String]: return Ok(22)
def ef_branch(a: Int, b: Int) -> List[Int]: return [a+b, a-b]
def ef_cell(a: Int, b: Int) -> Cell[Int]: return Cell(a+b)
def ef_values() -> List[Int]: return [1,2,3]
def ef_logged(a: Int, b: Int) -> Writer[StringMonoid].Pure[Int]:
    return writer[Writer[StringMonoid], Int]((String(b), a+b))


@fieldwise_init
struct EFFactory(MutableThunk):
    var value: Int
    comptime Out = List[Int]
    def call_mut(mut self) -> Self.Out:
        self.value += 1
        return [self.value]


@fieldwise_init
struct EFRead(BorrowCallable):
    var value: Int
    comptime Payload = Int
    comptime Result = Int
    def invoke(self, ref env: Int) raises Never capturing -> Int: return self.value + env


@fieldwise_init
struct EFReaderStep(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Reader[Int].Endpoint[Int, EFRead]
    def call(self, var acc: Int, var item: Int) -> Self.Out:
        return action[Reader[Int], Int](EFRead(acc+item))


@fieldwise_init
struct EFState(Unary):
    var value: Int
    comptime Arg = Int
    comptime Out = Tuple[Int, Int]
    def call(self, var state: Int) -> Self.Out: return (self.value+state, state+1)


@fieldwise_init
struct EFStateStep(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = State[Int].Endpoint[Int, EFState]
    def call(self, var acc: Int, var item: Int) -> Self.Out:
        return action[State[Int], Int](EFState(acc+item))


@fieldwise_init
struct EFStatePredicate(Unary):
    var value: Int
    comptime Arg = Int
    comptime Out = Tuple[Bool, Int]
    def call(self, var state: Int) -> Self.Out: return (self.value == 2, state+1)


def ef_state_predicate(x: Int) -> State[Int].Endpoint[Bool, EFStatePredicate]:
    return action[State[Int], Bool](EFStatePredicate(x))


def ef_basics() raises:
    var xs = ef_values()
    assert_equal(piped(xs.copy()).fold_effect[ResultFamily[String]](ef_add,0).get().raise_on_err(),6)
    assert_equal(fold_effect[ResultFamily[String]](ef_add,5,List[Int]()).raise_on_err(),5)
    assert_true(iterated(xs.copy()).all_effect[ResultFamily[String]](ef_positive).raise_on_err())
    assert_false(any_effect[ResultFamily[String]](ef_positive,List[Int]()).raise_on_err())
    assert_true(all_effect[ResultFamily[String]](ef_positive,List[Int]()).raise_on_err())
    assert_equal(piped(Optional(4)).fold_effect[ResultFamily[String]](ef_add,2).get().raise_on_err(),6)
    assert_equal(piped(Optional[Int]()).fold_effect[ResultFamily[String]](ef_add,2).get().raise_on_err(),2)
    var array: Array[Int,3] = [1,2,3]
    assert_equal(piped(array^).fold_effect[ResultFamily[String]](ef_add,0).get().raise_on_err(),6)
    var deque = Deque[Int]()
    deque.append(2); deque.append(4)
    assert_equal(piped(deque^).fold_effect[ResultFamily[String]](ef_add,0).get().raise_on_err(),6)
    var linked = LinkedList[Int]()
    linked.append(3); linked.append(5)
    assert_equal(piped(linked^).fold_effect[ResultFamily[String]](ef_add,0).get().raise_on_err(),8)
    var cursor = CombinatorRestarting(1)
    _ = cursor.__next__()
    assert_equal(iterated(cursor^).fold_effect[ResultFamily[String]](ef_add,0).raise_on_err(),5)
    var pair: List[Int] = [1,2]
    assert_equal(fold_effect[ListFamily](ef_branch,0,pair.copy()),[3,-1,1,-3])
    assert_equal(fold_effect[CellFamily](ef_cell,0,pair.copy()).value,3)
    assert_equal(run_writer[Writer[StringMonoid]](fold_effect[Writer[StringMonoid]](ef_logged,0,pair.copy())), (String("12"),3))
    assert_equal(run[Reader[Int]](piped(pair.copy()).fold_effect[Reader[Int]](EFReaderStep(),0).get(),5),13)
    assert_equal(run[State[Int]](iterated(pair^).fold_effect[State[Int]](EFStateStep(),0),10),(24,12))


def ef_stops() raises:
    var calls = ArcPointer(0)
    var pulls = 0
    def checked(a: Int,b: Int) {calls} -> Result[Int,String]:
        calls[] += 1
        if b == 3: return Err(String("stop"))
        return Ok(a+b)
    var failed = iterated(Counted(Pointer(to=pulls),0,6)).fold_effect[ResultFamily[String]](checked,0)
    assert_true(failed.is_err())
    assert_equal(calls[],3); assert_equal(pulls,3)
    calls[] = 0; pulls = 0
    def reaches(x: Int) {calls} -> Result[Bool,String]:
        calls[] += 1
        return Ok(x==2)
    assert_true(iterated(Counted(Pointer(to=pulls),0,6)).any_effect[ResultFamily[String]](reaches).raise_on_err())
    assert_equal(calls[],2); assert_equal(pulls,2)
    pulls = 0
    var stateful = iterated(Counted(Pointer(to=pulls),0,5)).any_effect[State[Int]](ef_state_predicate)
    assert_equal(pulls,0)
    assert_equal(run[State[Int]](stateful^,10),(True,12))
    assert_equal(pulls,2)
    calls[] = 0; pulls = 0
    assert_false(iterated(Counted(Pointer(to=pulls),0,6)).all_effect[ResultFamily[String]](reaches).raise_on_err())
    assert_equal(calls[],1); assert_equal(pulls,1)
    def absent(x: Int) -> Optional[Bool]: return None
    assert_false(iterated(Counted(Pointer(to=pulls),0,6)).any_effect[OptionalFamily](absent))
    assert_equal(pulls,2)
    # Branches already decided carry once, without calling the predicate again.
    calls[] = 0
    def branching(x: Int) {calls} -> List[Bool]:
        calls[] += 1
        return [False, True]
    var xs: List[Int] = [1,2]
    assert_equal(any_effect[ListFamily](branching,xs^),[False,True,True])
    assert_equal(calls[],2)
    calls[] = 0; pulls = 0
    def deferred(x: Int) {calls} -> Reader[Int].Pure[Bool]:
        calls[] += 1
        return Reader[Int].pure(x==2)
    var effect = iterated(Counted(Pointer(to=pulls),0,5)).any_effect[Reader[Int]](deferred)
    assert_equal(calls[],0); assert_equal(pulls,0)
    assert_true(run[Reader[Int]](effect^,7))
    assert_equal(calls[],2); assert_equal(pulls,2)


def ef_conditions() raises:
    assert_equal(piped(Result[Bool,String](Ok(True))).if_effect(ef_yes,ef_no).get().raise_on_err(),11)
    assert_equal(piped(Result[Bool,String](Ok(False))).if_effect(ef_yes,ef_no).get().raise_on_err(),22)
    assert_equal(if_effect[ResultFamily[String]](ef_yes,ef_no,Result[Bool,String](Ok(True))).raise_on_err(),11)
    var calls = ArcPointer(0)
    def selected() {calls} -> Result[Int,String]:
        calls[] += 1
        return Ok(4)
    assert_true(piped(Result[Bool,String](Err(String("condition")))).if_effect(selected,selected).get().is_err())
    assert_equal(calls[],0)
    assert_equal(piped(Result[Bool,String](Ok(True))).if_effect(selected,ef_no).get().raise_on_err(),4)
    assert_equal(calls[],1)
    var choices: List[Bool] = [True,False,True]
    assert_equal(piped(choices^).if_effect(EFFactory(0),EFFactory(10)).get(),[1,11,2])
    def left() -> Reader[Int].Pure[Int]: return Reader[Int].pure(1)
    def right() -> Reader[Int].Endpoint[Int, EFRead]: return action[Reader[Int],Int](EFRead(10))
    assert_equal(run[Reader[Int]](piped(Reader[Int].pure(False)).if_effect[Reader[Int]](left,right).get(),2),12)


def main() raises:
    ef_basics()
    ef_stops()
    ef_conditions()
