# error: invalid call to 'modify': lacking evidence to prove correctness
from fp.effects import State, modify

def keep[V: Movable & Deinitable](var value: V) -> V: return value^

def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    var action = modify[State[A]](keep[B])
    _ = action^

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
