"""Generic prefix/indexed return types and exact terminal errors through packages."""
from std.iter import Iterator, iter, next
from std.testing import assert_equal
from std.memory import ArcPointer
from fp.iteration import Iter, iterated, IndexedMapIterator, ZipWithIterator, TakeWhileIterator, DropWhileIterator
from fp.iteration import map_with_index, zip_with, take_while, drop_while, count_where, for_each, collect_fold
from fp.algebra import StringMonoid


def indexed[T: Movable & Deinitable,R: Movable & Deinitable,I: Iterator,//, F: def(var Int,var T)->R](var function:F,var source:I) -> Iter[IndexedMapIterator[T,R,I,F]] where I.Element==T:
    return iterated(source^).map_with_index(function^)

def paired[A: Movable & Deinitable,B: Movable & Deinitable,R: Movable & Deinitable,I:Iterator,J:Iterator,//,F:def(var A,var B)->R](var function:F,var source:I,var other:J) -> Iter[ZipWithIterator[A,B,R,I,J,F]] where I.Element==A and J.Element==B:
    return iterated(source^).zip_with(other^,function^)

def taking[T:Movable & Deinitable,I:Iterator,//,F:def(T)->Bool](var predicate:F,var source:I) -> Iter[TakeWhileIterator[T,I,F]] where I.Element==T:
    return iterated(source^).take_while(predicate^)

def dropping[T:Movable & Deinitable,I:Iterator,//,F:def(T)->Bool](var predicate:F,var source:I) -> Iter[DropWhileIterator[T,I,F]] where I.Element==T:
    return iterated(source^).drop_while(predicate^)

def count_forward[T:Movable & Deinitable,I:Iterator,E:Movable & Deinitable,//,F:def(T) raises E ->Bool](function:F,var source:I) raises E ->Int where I.Element==T:
    return iterated(source^).count_where[E=E](function)

def sink_forward[T:Movable & Deinitable,I:Iterator,E:Movable & Deinitable,//,F:def(var T) raises E ->NoneType](function:F,var source:I) raises E ->NoneType where I.Element==T:
    return iterated(source^).for_each[E=E](function)

def collect_forward[T:Movable & Deinitable,I:Iterator,E:Movable & Deinitable,//,F:def(var T) raises E ->Optional[String]](function:F,var source:I) raises E ->String where I.Element==T:
    return iterated(source^).collect_fold[M=StringMonoid,E=E](function)


@fieldwise_init
struct I12GenericFailure(Movable):
    var code:Int


def errors() raises:
    var calls=0
    def predicate(value:Int) raises I12GenericFailure {mut calls} ->Bool:
        calls+=1
        if value==2:raise I12GenericFailure(7)
        return True
    var caught=False
    try:_=count_forward[E=I12GenericFailure](predicate,iter(range(4)))
    except e:
        assert_equal(e.code,7)
        caught=True
    assert_equal(caught,True)
    assert_equal(calls,3)
    def sink(var value:Int) raises I12GenericFailure ->NoneType:
        if value==1:raise I12GenericFailure(8)
        return None
    caught=False
    try:sink_forward[E=I12GenericFailure](sink,iter(range(4)))
    except e:
        assert_equal(e.code,8)
        caught=True
    assert_equal(caught,True)
    def select(var value:Int) raises I12GenericFailure ->Optional[String]:
        if value==1:raise I12GenericFailure(9)
        return Optional(String(value))
    caught=False
    try:_=collect_forward[E=I12GenericFailure](select,iter(range(4)))
    except e:
        assert_equal(e.code,9)
        caught=True
    assert_equal(caught,True)


def origins(values:List[Int],anchor:List[Int]) raises:
    def view(var index:Int,var value:Int) {anchor} ->Span[Int,origin_of(anchor)]:
        return Span(anchor)
    var result=indexed(view,iter(values))
    var first=next(result)
    assert_equal(first[0],10)
    _=result^
    def both(var left:Int,var right:Int) {anchor} ->Span[Int,origin_of(anchor)]:
        return Span(anchor)
    var pairs=paired(both,iter(values),iter(values))
    var second=next(pairs)
    assert_equal(second[1],11)
    _=pairs^
    var native=iterated(iter(values)).zip(iter(anchor)).take(1)
    assert_equal(native^.to_list(),[(0,10)])
    var chained=iterated(iter(values)).chain(iter(anchor)).drop(1)
    assert_equal(chained^.to_list(),[1,2,10,11])


def main() raises:
    var limit=2
    def prefix(value:Int) {limit} ->Bool:return value<limit
    assert_equal(taking(prefix,iter(range(4))).to_list(),[0,1])
    assert_equal(dropping(prefix,iter(range(4))).to_list(),[2,3])
    var calls=0
    def combine(var a:Int,var b:Int) {mut calls} ->Int:
        calls+=1
        return a+b
    assert_equal(indexed(combine,iter(range(3))).to_list(),[0,2,4])
    assert_equal(calls,3)
    assert_equal(paired(combine,iter(range(3)),iter(range(3))).to_list(),[0,2,4])
    assert_equal(calls,6)
    errors()
    var values:List[Int]=[0,1,2]
    var anchor:List[Int]=[10,11]
    origins(values,anchor)
