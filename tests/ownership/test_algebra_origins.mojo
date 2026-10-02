"""A deferred computation preserves the origin of its captured native value."""
from fp.algebra import pure
from fp.effects import Reader, run
from std.testing import assert_equal

def preserve[origin:ImmOrigin](ref[origin] value:Int)->Pointer[Int,origin]:
    var environment=0
    var computation=pure[Reader[Int]](Pointer(to=value))
    return run[Reader[Int]](computation^,environment)

def main() raises:
    var value=7
    var result=preserve(value)
    assert_equal(result[],7)
    print("Reader captured origin preserved")
