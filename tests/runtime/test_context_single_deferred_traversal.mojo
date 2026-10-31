from fp.algebra import Applicative,OptionalFamily,ResultFamily,TraverseContract,traverse,StringMonoid
from fp.effects import Reader,State,Writer,ReaderT,StateT,WriterT,OptionalT,ResultT,action,run,run_writer
from fp.callables import OnceUnary,BorrowOnceCallable
from fp.data import Result,Ok,Err
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal,assert_true

@fieldwise_init
struct Read(BorrowOnceCallable):
    var item:Int
    var runs:ArcPointer[Int]
    comptime Payload=Int
    comptime Result=Int
    comptime Failure=String
    def invoke_once(deinit self,ref environment:Int) raises String capturing ->Int:
        self.runs[]+=1
        if environment<0:raise String("run failure")
        return self.item+environment

@fieldwise_init
struct ProduceRead(OnceUnary):
    var calls:ArcPointer[Int]
    var runs:ArcPointer[Int]
    comptime Arg=Int
    comptime Out=type_of(action[Reader[Int],Int](Read(0,ArcPointer(0))))
    comptime Error=Int
    def call_once(deinit self,var item:Int) raises Int ->Self.Out:
        self.calls[]+=1
        if item<0:raise 91
        return action[Reader[Int],Int](Read(item,self.runs^))

@fieldwise_init
struct Pure[I:Applicative](OnceUnary):
    comptime Arg=Int
    comptime Out=Self.I.Pure[Int]
    def call_once(deinit self,var value:Int)->Self.Out:return Self.I.pure(value+1)

def generic[I:Applicative](var value:Optional[Int]) raises TraverseContract[OptionalFamily,I,Optional[Int],Pure[I]].Error ->OptionalFamily.Traversed[I,Optional[Int],Pure[I]] where TraverseContract[OptionalFamily,I,Optional[Int],Pure[I]].Compatible:
    return traverse[I, OptionalFamily](value^,Pure[I]())

def main() raises:
    comptime I=Reader[Int]
    comptime C=TraverseContract[OptionalFamily,I,Optional[Int],ProduceRead]
    comptime assert C.Compatible
    comptime assert C.Error==Int
    var calls=ArcPointer(0)
    var runs=ArcPointer(0)
    var env=10
    for present in [False,True]:
        calls[]=0
        runs[]=0
        var source=Optional(7) if present else Optional[Int]()
        var pending=pipeline[OptionalFamily](source^).traverse[I](ProduceRead(calls,runs)).get()
        assert_equal(calls[],Int(present))
        assert_equal(runs[],0)
        var result=run[I](pending^,env)
        assert_equal(runs[],Int(present))
        assert_equal(Bool(result),present)
        if result:assert_equal(result.take(),17)
    calls[]=0
    runs[]=0
    var pending=traverse[I, ResultFamily[String]](Result[Int,String](Err("stored")),ProduceRead(calls,runs))
    assert_equal(calls[],0)
    var retained=run[I](pending^,env)
    assert_true(retained.is_err())
    assert_equal(runs[],0)
    var construction_error=0
    try:_=traverse[I, OptionalFamily](Optional(-1),ProduceRead(calls,runs))
    except error:construction_error=error
    assert_equal(construction_error,91)
    var execution=traverse[I, OptionalFamily](Optional(5),ProduceRead(calls,runs))
    env=-1
    var execution_error=String()
    try:_=run[I](execution^,env)
    except error:execution_error=error^
    assert_equal(execution_error,"run failure")
    env=10
    var read=run[I](generic[I](Optional(3)),env)
    assert_equal(read.take(),4)
    var state=run[State[Int]](generic[State[Int]](Optional(3)),10)
    assert_equal(state[0].take(),4)
    assert_equal(state[1],10)
    var written=run_writer[Writer[StringMonoid]](generic[Writer[StringMonoid]](Optional(3)))
    assert_equal(written[0],"")
    assert_equal(written[1].take(),4)
    var nested=run[I](generic[OptionalT[I]](Optional(3)),env)
    var inner=nested.take()
    assert_equal(inner.take(),4)
    var result_nested=run[I](generic[ResultT[I,String]](Optional(3)),env)
    var inner_result=result_nested^.raise_on_err()
    assert_equal(inner_result.take(),4)
