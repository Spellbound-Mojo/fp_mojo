"""Ordering, generic inference, receiver priority, empty input and source position."""
from fp.iteration import map_accumulate, iterated
from fp.callables import Binary, MutableBinary, OnceBinary, BinaryContract, RepeatableBinary
from std.iter import Iterator, next
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Source(Iterator):
    comptime Element = Int
    var index: Int
    var length: Int
    var pulls: ArcPointer[Int]
    def __next__(mut self) raises StopIteration -> Int:
        self.pulls[] += 1
        if self.index == self.length: raise StopIteration()
        self.index += 1
        return self.index

@fieldwise_init
struct Step(Binary, MutableBinary, OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Tuple[Int,Int]
    var calls: ArcPointer[Int]
    def call(self,var carry: Int,var item: Int) -> Self.Out: return (-1,-1)
    def call_once(deinit self,var carry: Int,var item: Int) -> Self.Out: return (-2,-2)
    def call_mut(mut self,var carry: Int,var item: Int) -> Self.Out:
        self.calls[] += 1
        return(carry+item,self.calls[])

def accumulated[A: Movable & Deinitable,Y: Movable & Deinitable,I: Iterator,F: BinaryContract & Movable & Deinitable](
    var step: F,var initial: A,var source: I
) raises F.Error -> Tuple[A,List[Y]] where F.First==A and F.Second==I.Element and F.Out==Tuple[A,Y] and RepeatableBinary[F]:
    return map_accumulate[Y=Y](step^,initial^,source^)

def stop(var carry: Int,var item: Int) raises StopIteration -> Tuple[Int,Int]:
    if item==2: raise StopIteration()
    return (carry+item,item)

def main() raises:
    var pulls=ArcPointer(0)
    var calls=ArcPointer(0)
    var empty=accumulated(Step(calls),7,Source(0,0,pulls))
    assert_equal(empty[0],7)
    assert_equal(len(empty[1]),0)
    assert_equal(pulls[],1)
    assert_equal(calls[],0)
    pulls[]=0
    var source=Source(0,4,pulls)
    assert_equal(next(source),1)
    var result=accumulated(Step(calls),10,source^)
    assert_equal(result[0],19)
    assert_equal(result[1],[1,2,3])
    assert_equal(pulls[],5)
    assert_equal(calls[],3)
    pulls[]=0
    var stopped=False
    try: _=iterated(Source(0,4,pulls)).map_accumulate(stop,0)
    except error:
        comptime assert type_of(error)==StopIteration
        stopped=True
    assert_equal(stopped,True)
    assert_equal(pulls[],2)
