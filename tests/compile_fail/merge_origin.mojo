# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import merge
def identity[T: Movable & Deinitable](var value: T) -> T: return value^
def projected(owner: List[Int]) -> Tuple[Span[Int, origin_of(owner)], Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View) thin -> View = identity[View]
    return merge(pointer, pointer)(view)
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Tuple[Span[Int, o], Span[Int, o]]:
    var local: List[Int] = [1]
    return projected(local)
def main(): pass
