# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import split
def identity[T: Movable & Deinitable](var value: T) -> T: return value^

def projected(left: List[Int], right: List[Int]) -> Tuple[Span[Int, origin_of(left)], Span[Int, origin_of(right)]]:
    var a = Span(left)
    var b = Span(right)
    comptime A = type_of(a)
    comptime B = type_of(b)
    var f: def(var A) thin -> A = identity[A]
    var g: def(var B) thin -> B = identity[B]
    return split(f, g)((a, b))
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Tuple[Span[Int, o], Span[Int, o]]:
    var local: List[Int] = [1]
    return projected(local, owner)
def main(): pass
