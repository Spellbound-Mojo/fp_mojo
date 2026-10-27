# error: origin_of(local_value)
from fp.algebra import OptionalFamily,StringMonoid,pure
from fp.effects import WriterT

comptime W=WriterT[OptionalFamily,StringMonoid]

def read_pointer[o:ImmOrigin](ref[o] value:Int)->Pointer[Int,o]:return Pointer(to=value)

def escape[o:ImmOrigin](ref[o] owner:Int)->W.Pure[Pointer[Int,o]]:
    var local_value=3
    return pure[W](read_pointer(local_value))

def main():
    var owner=0
    _=escape(owner)
