"""A heterogeneous deferred bind consumes its callback or cleans it up unused."""
from fp.algebra import pure, map, flat_map
from fp.effects import OptionalT, Reader, run
from fp.callables import OnceUnary, as_unary
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer
from std.testing import assert_equal
from test_attempt_once import Trace, Token

comptime Base = Reader[Int]
comptime Layer = OptionalT[Base]

def increment(var value:Int)->Int:
    return value+1

@fieldwise_init
struct Next(OnceUnary):
    var state:Token[1]
    var fail:Bool
    comptime Value = Layer.Pure[Int]
    comptime Arg = Int
    comptime Out = Layer.Mapped[Self.Value,type_of(as_unary(increment))]
    comptime Error = Token[2]
    def call_once(deinit self,var argument:Int) raises Token[2] -> Self.Out:
        self.state.trace[].calls+=1
        var value=argument+self.state.value
        if self.fail:
            raise Token[2](value,self.state.trace)
        return map[Layer](as_unary(increment),pure[Layer](value))

def main() raises:
    for present in [False,True]:
        for fail in [False,True]:
            var trace=ArcPointer(Trace(0,SIMD[DType.int64,4](0)))
            var optional=Optional[Int]()
            if present:
                optional=Optional(3)
            var environment=42
            var caught=False
            var value=0
            var got_present=False
            try:
                var result=run[Base](flat_map[Layer](Next(Token[1](10,trace),fail),pure[Base](optional^)),environment)
                got_present=Bool(result)
                if result:
                    value=result.take()
            except error:
                comptime assert type_of(error)==Token[2]
                caught=True
                value=error.value
            assert_equal(got_present,present and not fail)
            assert_equal(caught,present and fail)
            assert_equal(value,(13 if fail else 14) if present else 0)
            assert_equal(trace[].calls,Int(present))
            assert_equal(trace[].drops[1],1)
            assert_equal(Int(trace[].drops[2]),Int(present and fail))
    print("OptionalT Reader: heterogeneous branches, consuming callback, typed errors, cleanup")
