# error: origin_of(local)
from fp.data import Capture, Result

def fail[V: Movable & Deinitable](var value: V) raises V -> Int:
    raise value^

def check(anchor: List[Int], local: List[Int]):
    var view = Span(local)
    comptime Local = type_of(view)
    var other = Span(anchor)
    var bad: Result[Int, type_of(other)] = Capture[Local].take(view).run(fail[Local])
    _ = bad^

def main():
    var anchor: List[Int] = [3]
    var local: List[Int] = [7]
    check(anchor, local)
