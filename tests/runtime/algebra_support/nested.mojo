"""Shared public endpoints for mixed sums over deferred Writer computations."""
from fp.algebra import StringMonoid
from fp.effects import Reader, State, WriterT, OptionalT, ResultT, action, writer, run, run_writer
from fp._internal.errors import _propagate_error
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer
from std.testing import assert_equal

comptime Base[stateful:Bool] = State[Int] if stateful else Reader[Int]
comptime Logged[stateful:Bool] = WriterT[Base[stateful],StringMonoid]
comptime Stack[optional_first:Bool,stateful:Bool] = OptionalT[ResultT[Logged[stateful],Int]] if optional_first else ResultT[OptionalT[Logged[stateful]],Int]
comptime Payload[optional_first:Bool] = Result[Optional[Int],Int] if optional_first else Optional[Result[Int,Int]]


def payload[optional_first:Bool](value:Int,failure:Int)->Payload[optional_first]:
    comptime if optional_first:
        if failure==2:
            return rebind_var[Payload[optional_first]](Result[Optional[Int],Int](Err(502)))
        return rebind_var[Payload[optional_first]](Result[Optional[Int],Int](Ok(Optional[Int]() if failure==1 else Optional(value))))
    else:
        if failure==1:
            return rebind_var[Payload[optional_first]](Optional[Result[Int,Int]]())
        return rebind_var[Payload[optional_first]](Optional(Result[Int,Int](Err(502)) if failure==2 else Result[Int,Int](Ok(value))))


@fieldwise_init
struct Emit[optional_first:Bool,stateful:Bool](OnceUnary,BorrowOnceCallable):
    """A State endpoint consumes the state; a Reader endpoint borrows the environment."""
    var trace:ArcPointer[List[Int]]
    var marker:Int
    var delta:Int
    var failure:Int
    comptime Pair=Tuple[String,Payload[Self.optional_first]]
    comptime Output=Tuple[Self.Pair,Int] if Self.stateful else Self.Pair
    comptime Arg=Int
    comptime Out=Self.Output
    comptime Error=Int
    comptime Payload=Int
    comptime Result=Self.Output
    comptime Failure=Int
    def call_once(deinit self,var state:Int) raises Int ->Self.Output:
        return Self._emit(self.trace,self.marker,self.delta,self.failure,state)
    def invoke_once(deinit self,ref environment:Int) raises Int capturing ->Self.Output:
        return Self._emit(self.trace,self.marker,self.delta,self.failure,environment)
    @staticmethod
    def _emit(trace:ArcPointer[List[Int]],marker:Int,delta:Int,failure:Int,context:Int) raises Int ->Self.Output:
        trace[].append(marker)
        if failure==4:
            raise 704
        var pair=Tuple(String(marker),payload[Self.optional_first](context+delta,failure))
        comptime if Self.stateful:
            return rebind_var[Self.Output](Tuple(pair^,context+delta))
        else:
            return rebind_var[Self.Output](pair^)


comptime Endpoint[optional_first:Bool,stateful:Bool]=type_of(writer[Logged[stateful],Payload[optional_first]](action[Base[stateful],Tuple[String,Payload[optional_first]]](Emit[optional_first,stateful](ArcPointer(List[Int]()),0,0,0))))


def endpoint[optional_first:Bool,stateful:Bool](trace:ArcPointer[List[Int]],marker:Int,delta:Int,failure:Int)->Endpoint[optional_first,stateful]:
    return writer[Logged[stateful],Payload[optional_first]](action[Base[stateful],Tuple[String,Payload[optional_first]]](Emit[optional_first,stateful](trace,marker,delta,failure)))


def finish[optional_first:Bool,stateful:Bool,V:Movable & Deinitable](var value:V,environment:Int) raises Int ->Emit[optional_first,stateful].Output:
    # Adapt the two native frame signatures; each opaque run error is proved
    # independently before crossing this common test assertion boundary.
    var context=environment
    comptime if stateful:
        try:
            var output=run[State[Int]](run_writer[Logged[stateful]](value^),context)
            comptime assert type_of(output)==Emit[optional_first,stateful].Output
            return rebind_var[Emit[optional_first,stateful].Output](output^)
        except error:
            comptime assert type_of(error)==Int
            _propagate_error[Int](error^)
    else:
        try:
            var output=run[Reader[Int]](run_writer[Logged[stateful]](value^),context)
            comptime assert type_of(output)==Emit[optional_first,stateful].Output
            return rebind_var[Emit[optional_first,stateful].Output](output^)
        except error:
            comptime assert type_of(error)==Int
            _propagate_error[Int](error^)


@fieldwise_init
struct Next[optional_first:Bool,stateful:Bool](OnceUnary):
    var trace:ArcPointer[List[Int]]
    var failure:Int
    comptime Arg=Int
    comptime Out=Endpoint[Self.optional_first,Self.stateful]
    comptime Error=Int
    def call_once(deinit self,var value:Int) raises Int ->Self.Out:
        self.trace[].append(2)
        if self.failure==3:
            raise 703
        return endpoint[Self.optional_first,Self.stateful](self.trace,3,value,self.failure)


def assert_payload[optional_first:Bool](var value:Payload[optional_first],expected:Int,failure:Int) raises:
    var actual=0
    var absent=False
    var stored=0
    comptime if optional_first:
        var result=rebind_var[Result[Optional[Int],Int]](value^)
        try:
            var option=result^.raise_on_err()
            absent=not Bool(option)
            if option:
                actual=option.take()
        except error:
            stored=error
    else:
        var option=rebind_var[Optional[Result[Int,Int]]](value^)
        absent=not Bool(option)
        if option:
            try:
                actual=option.take().raise_on_err()
            except error:
                stored=error
    assert_equal(absent,failure==1)
    assert_equal(stored,502 if failure==2 else 0)
    assert_equal(actual,expected if failure==0 else 0)
