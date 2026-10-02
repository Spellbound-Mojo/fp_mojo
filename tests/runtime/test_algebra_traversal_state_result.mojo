"""Deferred traversal stops pulls at stored/native failure in either stack order."""
from fp.algebra import traverse, ListFamily
from fp.effects import run
from fp.callables import Unary
from algebra_support import split_pair
from fp.data import Result, Ok, Err
from fp._internal.errors import _propagate_error
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer
from std.testing import assert_equal
from algebra_support.state_result import Base, Stack, Endpoint, step
from algebra_support import ints
from algebra_support.iterators import Counted

@fieldwise_init
struct Produce[retain:Bool](Unary):
    var trace:ArcPointer[List[Int]]
    var failure:Int
    comptime Arg=Int
    comptime Out=Endpoint[Self.retain]
    comptime Error=Error
    def call(self,var item:Int) raises ->Endpoint[Self.retain]:
        self.trace[].append(100+item)
        if item==3 and self.failure==3:
            raise Error("native producer failure")
        return step[Self.retain](self.trace,item,item,self.failure if item==3 else 0)

def check[retain:Bool]() raises:
    comptime I=Stack[retain]
    comptime Data=Result[List[Int],Int]
    comptime Out=Tuple[Data,Int] if retain else Result[Tuple[List[Int],Int],Int]
    for count in [0,2,5]:
        for failure in range(4):
            var pulls=0
            var trace=ArcPointer(List[Int]())
            var computation:type_of(traverse[ListFamily,I](Produce[retain](trace,failure),Counted(Pointer(to=pulls),0,count)))
            try:
                computation=traverse[ListFamily,I](Produce[retain](trace,failure),Counted(Pointer(to=pulls),0,count))
            except error:
                comptime assert type_of(error)==Never
                _propagate_error[Never](error^)
            assert_equal(pulls,0)
            assert_equal(len(trace[]),0)
            var output=Optional[Out]()
            var caught=False
            try:
                var value=run[Base[retain]](computation^,10)
                comptime assert type_of(value)==Out
                output=Optional(rebind_var[Out](value^))
            except error:
                comptime assert type_of(error)==Error
                caught=True
                assert_equal(String(rebind_var[Error](error^)),"native producer failure" if failure==3 else "native action failure")
            var stopped=count==5 and failure!=0
            var produced=3 if stopped else count
            assert_equal(pulls,produced if stopped else count+1)
            assert_equal(len(trace[]),produced*2-Int(caught and failure==3))
            for index in range(produced):
                assert_equal(trace[][index*2],101+index)
                if index*2+1<len(trace[]):
                    assert_equal(trace[][index*2+1],index+1)
            assert_equal(caught,count==5 and failure>=2)
            if output:
                var data:Data
                var state=Optional[Int]()
                comptime if retain:
                    var first=Optional[Data]()
                    var second=Optional[Int]()
                    split_pair(rebind_var[Tuple[Data,Int]](output.take()),first,second)
                    data=first.take()
                    state=second^
                else:
                    var result=rebind_var[Result[Tuple[List[Int],Int],Int]](output.take())
                    try:
                        var first=Optional[List[Int]]()
                        var second=Optional[Int]()
                        split_pair(result^.raise_on_err(),first,second)
                        data=Data(Ok(first.take()))
                        state=second^
                    except stored:
                        data=Data(Err(stored))
                assert_equal(data.is_err(),stopped)
                assert_equal(Bool(state),retain or not stopped)
                if state:
                    assert_equal(state.value(),16 if stopped else 10 if count==0 else 13 if count==2 else 25)
                var values=Optional[List[Int]]()
                var error_code=0
                try:
                    values=Optional(data^.raise_on_err())
                except stored:
                    error_code=stored
                assert_equal(error_code,3 if stopped else 0)
                if values:
                    assert_equal(values.value(),List[Int]() if count==0 else ints(11,13) if count==2 else ints(11,13,16,20,25))

def main() raises:
    check[True]()
    check[False]()
    print("State/Result traversal: deferred pulls, retained/discarded state, producer/action failures")
