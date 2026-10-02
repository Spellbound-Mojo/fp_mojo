from algebra_support.arrows import Produce, ReadStep, StateStep, ReadInt
from fp.algebra import traverse, ListFamily
from fp.effects import Reader, State, StateT, action, run
from fp.callables import Unary, OnceUnary
from std.memory import ArcPointer
from std.testing import assert_equal
from algebra_support.iterators import Counted
from algebra_support import ints

comptime Branching=StateT[ListFamily,Int]

@fieldwise_init
struct Branch(OnceUnary,Copyable):
    var item:Int
    comptime Arg=Int
    comptime Out=List[Tuple[Int,Int]]
    def call_once(deinit self,var state:Int)->List[Tuple[Int,Int]]:
        if self.item==0:
            return []
        return [Tuple(self.item,state),Tuple(self.item*10,state+1)]

@fieldwise_init
struct Branches(Unary):
    var calls:ArcPointer[Int]
    comptime Arg=Int
    comptime Out=type_of(action[Branching,Int](Branch(0)))
    def call(self,var item:Int)->Self.Out:
        self.calls[]+=1
        return action[Branching,Int](Branch(item))

def check_state_over_list() raises:
    # One producer call per item; every live branch runs the prepared
    # computation on its own state, and a dead carrier stops the pulls.
    var calls=ArcPointer(Int(0))
    var output=run[Branching](traverse[ListFamily,Branching](Branches(calls),[1,2]),0)
    assert_equal(calls[],2)
    assert_equal(len(output),4)
    var expected=[ints(1,2),ints(1,20),ints(10,2),ints(10,20)]
    var states=[0,1,1,2]
    for index in range(4):
        assert_equal(output[index][0],expected[index])
        assert_equal(output[index][1],states[index])
    calls[]=0
    var stopped=run[Branching](traverse[ListFamily,Branching](Branches(calls),[1,0,3]),0)
    assert_equal(len(stopped),0)
    assert_equal(calls[],2)

def main() raises:
    for count in [0,3]:
        var pulls=0
        var calls=ArcPointer(Int(0))
        var reader=traverse[ListFamily,Reader[Int]](Produce[False](calls),Counted(Pointer(to=pulls),0,count))
        assert_equal(pulls,0)
        assert_equal(calls[],0)
        var environment=10
        var values=run[Reader[Int]](reader^,environment)
        assert_equal(values,List[Int]() if count==0 else ints(11,12,13))
        assert_equal(pulls,count+1)
        assert_equal(calls[],count)
        pulls=0
        calls[]=0
        var state=traverse[ListFamily,State[Int]](Produce[True](calls),Counted(Pointer(to=pulls),0,count))
        assert_equal(pulls,0)
        assert_equal(calls[],0)
        var output=run[State[Int]](state^,10)
        assert_equal(output[0],List[Int]() if count==0 else ints(11,13,16))
        assert_equal(output[1],10 if count==0 else 16)
        assert_equal(pulls,count+1)
        assert_equal(calls[],count)
    check_state_over_list()
    print("deferred traversal: Reader, State and State over List")
