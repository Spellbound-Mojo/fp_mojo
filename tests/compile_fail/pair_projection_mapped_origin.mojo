# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import first
def identity[T: Movable & Deinitable](var value: T) -> T: return value^
def increment(value: Int) -> Int: return value + 1
def projected(owner: List[Int]) -> Tuple[Span[Int, origin_of(owner)], Int]:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View) thin -> View = identity[View]
    return first[Int](pointer)((view, 9))
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Tuple[Span[Int, o], Int]:
    var local: List[Int] = [1]
    return projected(local)
def main(): pass
