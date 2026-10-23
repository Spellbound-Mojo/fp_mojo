"""Alignment preserves side tags, pull order, origins and owned payloads."""
from fp.iteration import align, align_with, pad_zip, iterated, AlignWithIterator
from fp.data import Ior, Left, Right, Both
from fp.callables import MutableUnary
from std.iter import Iterator, IterableOwned, next, iter, empty
from std.itertools import count
from std.memory import ArcPointer
from std.testing import assert_equal


def i4_total(var value: Ior[Int,Int]) -> Int:
    if value.isa[Left[Int]](): return value[Left[Int]].value
    if value.isa[Right[Int]](): return value[Right[Int]].value
    return value[Both[Int,Int]].left + value[Both[Int,Int]].right


def i4_done[I: Iterator](mut value: I) raises where conforms_to(I.Element, Deinitable):
    for _ in range(2):
        var stopped = False
        try: _ = next(value)
        except StopIteration: stopped = True
        assert_equal(stopped, True)


@fieldwise_init
struct I4Source(Iterator, IterableOwned):
    comptime Element = Int
    comptime IteratorOwnedType = Self
    var position: Int
    var end: Int
    var id: Int
    var pulls: ArcPointer[List[Int]]
    var drops: ArcPointer[Int]
    def __iter__(var self) -> Self:
        self.position = 0
        return self^
    def __next__(mut self) raises StopIteration -> Int:
        var value = self.position
        self.position += 1
        self.pulls[].append(self.id * 100 + value)
        if value == self.end: raise StopIteration()
        return value
    def bounds(self) -> Tuple[Int,Optional[Int]]:
        return (max(0,self.end-self.position),Optional(max(0,self.end-self.position)))
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct I4Token(Movable):
    var value: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct I4Mapper(MutableUnary):
    comptime Arg = Ior[Int,Int]
    comptime Out = I4Token
    var count: Int
    var drops: ArcPointer[Int]
    def call_mut(mut self, var value: Self.Arg) -> Self.Out:
        self.count += 1
        return I4Token(String(i4_total(value^) + self.count), self.drops)


def i4_generic[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, J: Iterator, //, F: def(var T) -> U](var f:F,var source:I,var other:J) -> AlignWithIterator[A,B,U,I,J,F] where I.Element==A and J.Element==B and T==Ior[A,B]:
    return align_with[A=A,B=B,T=T,U=U](f^,source^,other^)


def tags() raises:
    for left_size in range(4):
        for right_size in range(4):
            var values = iterated(range(left_size)).align(range(10,10+right_size))
            assert_equal(values.bounds()[0], max(left_size,right_size))
            assert_equal(values.bounds()[1].value(), max(left_size,right_size))
            for index in range(max(left_size,right_size)):
                var item = next(values)
                if index < left_size and index < right_size:
                    assert_equal(item.isa[Both[Int,Int]](), True)
                    assert_equal(item[Both[Int,Int]].left, index)
                    assert_equal(item[Both[Int,Int]].right, index+10)
                elif index < left_size:
                    assert_equal(item.isa[Left[Int]](), True)
                    assert_equal(item[Left[Int]].value, index)
                else:
                    assert_equal(item.isa[Right[Int]](), True)
                    assert_equal(item[Right[Int]].value, index+10)
            i4_done(values)
            assert_equal(values.bounds()[1].value(),0)
    assert_equal(iterated(count()).align_with(range(2),i4_total).take(4).to_list(),[0,2,2,3])
    var unknown=align(count(),range(1))
    assert_equal(Bool(unknown.bounds()[1]),False)


def traces() raises:
    var pulls = ArcPointer(List[Int]())
    var drops = ArcPointer(0)
    var values = align(I4Source(1,3,1,pulls,drops),I4Source(1,2,2,pulls,drops))
    assert_equal(len(pulls[]),0)
    assert_equal(values.bounds()[0],2)
    assert_equal(i4_total(next(values)),2)
    assert_equal(i4_total(next(values)),2)
    i4_done(values)
    assert_equal(pulls[],[101,201,102,202,103])
    _ = values^
    assert_equal(drops[],2)
    pulls[].clear()
    var right_tail = align(I4Source(0,0,1,pulls,drops),I4Source(0,2,2,pulls,drops))
    assert_equal(i4_total(next(right_tail)),0)
    assert_equal(i4_total(next(right_tail)),1)
    i4_done(right_tail)
    assert_equal(pulls[],[100,200,201,202])
    _ = right_tail^
    assert_equal(drops[],4)
    pulls[].clear()
    var abandoned = iterated(I4Source(0,5,1,pulls,drops)).pad_zip(I4Source(0,4,2,pulls,drops))
    assert_equal(len(pulls[]),0)
    _ = next(abandoned)
    _ = abandoned^
    assert_equal(pulls[],[100,200])
    assert_equal(drops[],6)


def callbacks() raises:
    assert_equal(iterated(range(2)).align_with(range(3),i4_total).to_list(),[0,2,2])
    var calls = 0
    @always_inline
    def captured(var value: Ior[Int,Int]) {mut calls} -> Int:
        calls += 1
        return i4_total(value^) + calls
    var mapped = i4_generic(captured, iter(range(2)), iter(range(3)))
    assert_equal(calls,0)
    assert_equal(iterated(mapped^).to_list(),[1,4,5])
    assert_equal(calls,3)
    var drops = ArcPointer(0)
    var library = align_with(I4Mapper(0,drops),range(2),range(3))
    var first = next(library)
    assert_equal(first.value,"1")
    _ = first^
    var second = next(library)
    assert_equal(second.value,"4")
    _ = second^
    _ = library^
    assert_equal(drops[],2)
    var bias = I4Token("owned captured heap text",drops)
    @always_inline
    def owning(var value: Ior[Int,Int]) {var bias^} -> Int:
        return i4_total(value^) + bias.value.byte_length()
    var held = iterated(range(2)).align_with(range(1),owning^)
    assert_equal(next(held),24)
    _ = held^
    assert_equal(drops[],3)


def owned_and_origins() raises:
    var drops = ArcPointer(0)
    var left = List[I4Token]()
    left.append(I4Token("left long heap payload",drops))
    left.append(I4Token("unconsumed",drops))
    var right = List[I4Token]()
    right.append(I4Token("right long heap payload",drops))
    var padded = pad_zip(left^,right^)
    var pair = next(padded)
    var a=pair[0].unsafe_take()
    var b=pair[1].unsafe_take()
    assert_equal(a.value,"left long heap payload")
    assert_equal(b.value,"right long heap payload")
    _ = a^
    _ = b^
    _ = padded^
    assert_equal(drops[],3)
    var more = List[I4Token]()
    more.append(I4Token("right only",drops))
    var tail = iterated(empty[I4Token]()).pad_zip(more^)
    var only=next(tail)
    assert_equal(Bool(only[0]),False)
    var c=only[1].unsafe_take()
    assert_equal(c.value,"right only")
    _ = c^
    i4_done(tail)
    assert_equal(drops[],4)
    var anchors: List[String] = ["borrowed heap text"]
    var borrowed = align(iter(anchors),empty[Int]())
    var item = next(borrowed)
    assert_equal(item[Left[String]].value,"borrowed heap text")
    i4_done(borrowed)
    var address = Pointer(to=anchors)
    var pointers = List[type_of(address)]()
    pointers.append(address)
    var located = align(pointers^,empty[Int]())
    var borrowed_payload = next(located)
    assert_equal(borrowed_payload[Left[type_of(address)]].value[][0], "borrowed heap text")


def main() raises:
    tags()
    traces()
    callbacks()
    owned_and_origins()
