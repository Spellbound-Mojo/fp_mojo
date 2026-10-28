# error: cannot implicitly convert
from fp.functions import untupled
def keep[T: Movable & Deinitable](var pair: Tuple[T, T]) -> Tuple[T, T]: return pair^
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Tuple[Span[Int, o], Span[Int, o]]:
    var local: List[Int] = [1]
    var view = Span(local)
    comptime View = type_of(view)
    var pointer: def(var Tuple[View, View]) thin -> Tuple[View, View] = keep[View]
    return untupled(pointer)(view, view)
def main(): pass
