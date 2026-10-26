# error: origin_of(local)
from fp.callables import as_unary

def identity[V: Movable & Deinitable](var value: V) -> V:
    return value^

def check(anchor: List[Int], local: List[Int]):
    var view = Span(local)
    var other = Span(anchor)
    comptime View = type_of(view)
    var pointer: def(var View) thin -> View = identity[View]
    var callback = as_unary(pointer)
    var wrong: type_of(other) = callback(view)
    _ = wrong

def main():
    var first: List[Int] = [3]
    var second: List[Int] = [7]
    check(first, second)
