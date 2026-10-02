# error: origin_of(local_value)
from fp.algebra import pure
from fp.effects import Reader, run

def read_pointer[origin:ImmOrigin](ref[origin] value:Int)->Pointer[Int,origin]:
    return Pointer(to=value)

def escape[origin:ImmOrigin](ref[origin] owner:Int)->Pointer[Int,origin]:
    var local_value=3
    var environment=0
    # Both pointers are immutable: rejection must concern the captured origin,
    # not a mutable/immutable pointer mismatch.
    var computation=pure[Reader[Int]](read_pointer(local_value))
    return run[Reader[Int]](computation^,environment)

def main():
    var owner=0
    _=escape(owner)
