"""Public transformer aliases retain lifting in native return annotations."""
from fp.algebra import pure, IdentityFamily
from fp.effects import OptionalT, ResultT, Reader, State, run, lift
from std.testing import assert_equal

comptime OptionalReader=OptionalT[Reader[Int]]
comptime ResultState=ResultT[State[Int],Int]

def optional_lift(var value:Int)->type_of(lift[OptionalReader](pure[Reader[Int]](Int()))):
    return lift[OptionalReader](pure[Reader[Int]](value))

def result_lift(var value:Int)->type_of(lift[ResultState](pure[State[Int]](Int()))):
    return lift[ResultState](pure[State[Int]](value))

def main() raises:
    var optional=lift[OptionalT[IdentityFamily]](3)
    assert_equal(optional.take(),3)
    var result=lift[ResultT[IdentityFamily,Int]](4)
    assert_equal(result.is_ok(),True)
    var environment=9
    var deferred=run[Reader[Int]](optional_lift(5),environment)
    assert_equal(deferred.take(),5)
    var pair=run[State[Int]](result_lift(6),environment)
    assert_equal(pair[0].is_ok(),True)
    assert_equal(pair[1],9)
    print("Transformer aliases: native lift signatures and Identity specializations")
