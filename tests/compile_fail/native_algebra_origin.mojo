# error: invalid call to 'map': lacking evidence to prove correctness
from fp.algebra import map, OptionalFamily

def keep[V: Movable & Deinitable](var value: V) -> V: return value^

def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    var laundered = map[OptionalFamily](keep[B], Optional(a))
    _ = laundered^

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
