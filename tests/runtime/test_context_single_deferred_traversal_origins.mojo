from fp.algebra import OptionalFamily, ResultFamily, traverse
from fp.effects import Reader,run
from fp.callables import OnceUnary
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from std.testing import assert_equal
from test_context_transport_error_mapping_origins import EnvRaises,Retaining,Inner,Outer

@fieldwise_init
struct ProduceEnvironment(OnceUnary):
    comptime Arg=Int
    comptime Out=EnvRaises
    def call_once(deinit self,var value:Int)->Self.Out:return EnvRaises()

@fieldwise_init
struct ProduceRetaining(OnceUnary):
    comptime Arg=Int
    comptime Out=Retaining
    def call_once(deinit self,var value:Int)->Self.Out:return Retaining()

def check(owner:List[Int],failure_owner:List[Int]) raises:
    comptime Value=type_of(Span(owner))
    comptime Failure=type_of(Span(failure_owner))
    comptime R=Reader[Int]
    def keep(var value:Value)->R.Pure[Value]:return R.pure(value)
    var env=0
    var pending=pipeline(Optional(Span(owner))).traverse[R](keep).get()
    var output=run[R](pending^,env)
    assert_equal(output.value().unsafe_ptr()==Span(owner).unsafe_ptr(),True)
    var failed=pipeline(Result[Value,Failure](Err(Span(failure_owner)))).traverse[R](keep).get()
    var retained=run[R](failed^,env)
    assert_equal(retained._err().value.unsafe_ptr()==Span(failure_owner).unsafe_ptr(),True)
    var pending_error=traverse[EnvRaises.Family, OptionalFamily](Optional(1),ProduceEnvironment())
    var caught=False
    try:_=run[EnvRaises.Family](pending_error^,failure_owner)
    except error:
        comptime assert type_of(error)==Failure
        caught=error.unsafe_ptr()==Span(failure_owner).unsafe_ptr()
    assert_equal(caught,True)
    var absent=traverse[EnvRaises.Family, OptionalFamily](Optional[Int](),ProduceEnvironment())
    caught=False
    var was_absent=False
    try:
        var result=run[EnvRaises.Family](absent^,failure_owner)
        was_absent=not Bool(result._ok().value)
    except error:caught=True
    assert_equal(caught,False)
    assert_equal(was_absent,True)
    var outer=pipeline(Optional(3)).traverse[Outer](ProduceRetaining()).get()
    var inner=run[Outer](outer^,owner)
    var result=run[Inner](inner^,2)
    assert_equal(result._ok().value.value(),owner[0]+2)

def main() raises:
    check([7,8],[11,12])
