# error: origin_of(local)
from fp.data import Capture
from fp.data import Result

def callback[V: Copyable & Deinitable](mut state: Int, var value: V, /, var **options: Int) raises V -> V:
    if state > 0: raise value^
    return value^

def check(anchor: List[Int], local: List[Int]):
    var view = Span(local)
    var other = Span(anchor)
    var state = 0
    var bad: Result[type_of(other), type_of(other)] = Capture[type_of(view)].mutable(state).take(view).kwargs(extra=1).run(callback[type_of(view)])
    _ = bad^

def main():
    var a: List[Int] = [3]
    var b: List[Int] = [7]
    check(a, b)
