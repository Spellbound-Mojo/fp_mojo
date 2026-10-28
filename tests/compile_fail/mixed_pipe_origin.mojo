# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import pipe, Identity
def identity[T: Movable & Deinitable](var value: T) -> T: return value^
def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    var view = Span(local)
    comptime View = type_of(view)
    var pointer: def(var View) thin -> View = identity[View]
    return pipe(view, pointer, Identity[View]())
def main(): pass
