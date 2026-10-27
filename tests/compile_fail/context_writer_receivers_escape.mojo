# error: origin_of(local_value)
from fp.callables import MutableBinary, call_repeated
from fp.algebra import StringMonoid
from fp.effects.writer import _WriterCombine

@fieldwise_init
struct Keep[V: Movable & Deinitable](MutableBinary):
    comptime First = Self.V
    comptime Second = Int
    comptime Out = Self.V
    def call_mut(mut self, var value: Self.V, var unused: Int) -> Self.Out:
        return value^

def read_pointer[o: ImmOrigin](ref[o] value: Int) -> Pointer[Int, o]:
    return Pointer(to=value)

def escape[o: ImmOrigin](ref[o] owner: Int) -> Tuple[String, Pointer[Int, o]]:
    var local_value = 3
    var view = read_pointer(local_value)
    var combine = _WriterCombine[StringMonoid, Keep[type_of(view)]](Keep[type_of(view)]())
    return call_repeated(combine, Tuple(String("a"), view), Tuple(String("b"), 1))

def main():
    var owner = 0
    _ = escape(owner)
