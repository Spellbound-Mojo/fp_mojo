# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import tupled
def first[T: Movable & Deinitable](var left: T, var right: T) -> T: return left^
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    var view = Span(local)
    comptime View = type_of(view)
    var pointer: def(var View, var View) thin -> View = first[View]
    return tupled(pointer)((view, view))
def main(): pass
