# error: origin_of(local)
from fp.data import Capture, Result

def callback[V: Copyable & Deinitable](var first: V, var second: V, var third: V) raises V -> V:
    raise second^

def check(anchor: List[Int], local: List[Int]):
    var view = Span(local)
    var other = Span(anchor)
    var bad: Result[type_of(other), type_of(other)] = Capture[type_of(view)].args(view, view, view).run(callback[type_of(view)])
    _ = bad^

def main():
    var a: List[Int] = [3]
    var b: List[Int] = [7]
    check(a, b)
