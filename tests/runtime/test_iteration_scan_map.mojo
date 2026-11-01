"""Lazy carry/output transitions without copying, including generic forwarding."""
from fp.iteration import iterated, scan_map, ScanMapIterator
from fp.callables import MutableBinary, Binary
from algebra_support.scans import I5Carry, I5Input, I5Output
from std.iter import Iterator, IterableOwned, next, iter
from std.itertools import count
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct I5Step(MutableBinary):
    comptime First = I5Carry
    comptime Second = I5Input
    comptime Out = Tuple[I5Carry,I5Output]
    var calls: ArcPointer[Int]
    var outputs: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def call_mut(mut self, var carry: Self.First, var item: Self.Second) -> Self.Out:
        self.calls[] += 1
        carry.total += item.value
        return (carry^,I5Output("output="+String(self.calls[]),self.outputs))
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct I5Source(Iterator, IterableOwned):
    comptime Element = Int
    comptime IteratorOwnedType = Self
    var position: Int
    var end: Int
    var pulls: ArcPointer[List[Int]]
    def __iter__(var self) -> Self:
        self.position=0
        return self^
    def __next__(mut self) raises StopIteration -> Int:
        var value=self.position
        self.position+=1
        self.pulls[].append(value)
        if value==self.end: raise StopIteration()
        return value


def i5_step(var carry: I5Carry,var item: Int)->Tuple[I5Carry,String]:
    carry.total+=item
    var output=String(carry.total)
    return (carry^,output^)


def i5_scalar(var carry: Int,var item: Int)->Tuple[Int,Int]:
    return (carry+item,carry+item)


def i5_generic[A: Movable & Deinitable,T: Movable & Deinitable,Y: Movable & Deinitable,R: Movable & Deinitable,I:Iterator,//,F:def(var A,var T)->R](var function:F,var initial:A,var source:I)->ScanMapIterator[A,T,Y,I,F] where I.Element==T and R==Tuple[A,Y]:
    return scan_map[A=A,T=T,Y=Y](source^,initial^,function^)


def i5_done[I:Iterator](mut value:I) raises where conforms_to(I.Element,Deinitable):
    for _ in range(2):
        var stopped=False
        try: _=next(value)
        except StopIteration: stopped=True
        assert_equal(stopped,True)


def demand() raises:
    var pulls=ArcPointer(List[Int]())
    var drops=ArcPointer(0)
    var values=iterated(I5Source(1,4,pulls)).scan_map(i5_step,I5Carry(10,drops))
    assert_equal(len(pulls[]),0)
    assert_equal(next(values),"11")
    assert_equal(next(values),"13")
    assert_equal(next(values),"16")
    i5_done(values)
    assert_equal(pulls[],[1,2,3,4])
    _=values^
    assert_equal(drops[],1)
    pulls[].clear()
    var empty=scan_map(I5Source(0,0,pulls),I5Carry(10,drops),i5_step)
    i5_done(empty)
    assert_equal(pulls[],[0])
    _=empty^
    assert_equal(drops[],2)
    var abandoned=scan_map(I5Source(0,3,pulls),I5Carry(10,drops),i5_step)
    _=abandoned^
    assert_equal(drops[],3)
    assert_equal(pulls[],[0])
    assert_equal(iterated(count()).scan_map(i5_scalar,0).take(4).to_list(),[0,1,3,6])


def ownership() raises:
    for take_count in range(4):
        var carries=ArcPointer(0)
        var inputs=ArcPointer(0)
        var outputs=ArcPointer(0)
        var captures=ArcPointer(0)
        var calls=ArcPointer(0)
        var source=List[I5Input]()
        for i in range(3): source.append(I5Input(i,inputs))
        var values=iterated(source^).scan_map(I5Step(calls,outputs,captures),I5Carry(0,carries))
        assert_equal(calls[],0)
        assert_equal(inputs[],0)
        var kept=List[I5Output]()
        for i in range(take_count):
            kept.append(next(values))
            assert_equal(kept[i].text,"output="+String(i+1))
        assert_equal(inputs[],take_count)
        assert_equal(calls[],take_count)
        _=values^
        assert_equal(carries[],1)
        assert_equal(captures[],1)
        assert_equal(inputs[],3)
        assert_equal(outputs[],0)
        _=kept^
        assert_equal(outputs[],take_count)


def native_and_origins() raises:
    var calls=0
    var drops=ArcPointer(0)
    var capture=I5Carry(10,drops)
    @always_inline
    def step(var carry:Int,var item:Int) {var capture^,mut calls}->Tuple[Int,String]:
        calls+=1
        capture.total+=1
        return (carry+item,String(carry+item+capture.total))
    var result=i5_generic(step^,0,iter(range(3)))
    assert_equal(calls,0)
    assert_equal(next(result),"11")
    assert_equal(next(result),"13")
    _=result^
    assert_equal(calls,2)
    assert_equal(drops[],1)
    i5_borrow(7)
    var source:List[Int]=[1,2]
    assert_equal(iterated(iter(source)).scan_map(i5_scalar,0).to_list(),[1,3])


@fieldwise_init
struct I5PointerStep[o:ImmOrigin](Binary):
    comptime First=Pointer[Int,Self.o]
    comptime Second=Int
    comptime Out=Tuple[Self.First,Self.First]
    def call(self,var first:Self.First,var second:Int)->Self.Out:
        return (first,first)


def main() raises:
    demand()
    ownership()
    native_and_origins()


def i5_borrow[o:ImmOrigin](ref[o] anchor: Int) raises:
    var address=Pointer(to=anchor)
    var borrowed=iterated(range(2)).scan_map[A=Pointer[Int,o],T=Int,Y=Pointer[Int,o]](I5PointerStep[o](),address)
    assert_equal(next(borrowed)[],7)
    assert_equal(next(borrowed)[],7)
    i5_done(borrowed)
    var native=i5_thin[Pointer[Int,o],Int,Pointer[Int,o]](i5_pointer[o],address,range(2))
    assert_equal(next(native)[],7)
    assert_equal(next(native)[],7)
    i5_done(native)


def i5_thin[A:Movable & Deinitable,T:Movable & Deinitable,Y:Movable & Deinitable,I:Iterator](function:def(var A,var T) thin -> Tuple[A,Y],var initial:A,var source:I)->ScanMapIterator[A,T,Y,I] where I.Element==T:
    return scan_map[A,T,Y,I](source^,initial^,function)


def i5_pointer[o:ImmOrigin](var carry:Pointer[Int,o],var item:Int)->Tuple[Pointer[Int,o],Pointer[Int,o]]:
    return (carry,carry)
