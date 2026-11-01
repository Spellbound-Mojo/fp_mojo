# error: origin_of(lease)
from fp._internal.exclusive import _ExclusiveCell, _exclusive
from std.memory import ArcPointer

def escape[o: ImmOrigin](ref[o] owner: ArcPointer[_ExclusiveCell[Int]]) -> Pointer[Int, o.unsafe_mut_cast[True]()]:
    var lease = _exclusive(owner)
    return Pointer(to=lease.value())

def main():
    var owner = ArcPointer(_ExclusiveCell(Int32(0), 1))
    var escaped = escape(owner)
    escaped[] = 2
