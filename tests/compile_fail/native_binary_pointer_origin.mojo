# error: cannot implicitly convert
# error: origin_of(local)
from fp.callables import as_binary
def keep[T: Movable & Deinitable](var first: T, var second: T) -> T:
    _ = second^
    return first^
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    var view = Span(local)
    comptime View = type_of(view)
    var pointer: def(var View, var View) thin -> View = keep[View]
    return as_binary(pointer)(view, view)
def main(): pass
