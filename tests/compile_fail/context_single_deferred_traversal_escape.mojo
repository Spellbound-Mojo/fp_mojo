# error: origin_of(local_value)
from fp.algebra import OptionalFamily, sequence
from fp.effects import Reader,run

def read_pointer[o:ImmOrigin](ref[o] value:Int)->Pointer[Int,o]:return Pointer(to=value)

def escape[o:ImmOrigin](ref[o] owner:Int)->Optional[Pointer[Int,o]]:
    var local_value=3
    var environment=0
    comptime R=Reader[Int]
    var pending=sequence[R, OptionalFamily](Optional(R.pure(read_pointer(local_value))))
    return run[R](pending^,environment)

def main():
    var owner=0
    _=escape(owner)
