# error: origin_of(local)
from fp._binding_architecture import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int
from fp.data import Result
def fail[T: Movable & Deinitable](var value: T) raises T -> Int: raise value^
def check(anchor: List[Int], local: List[Int]):
    var view = Span(local)
    var other = Span(anchor)
    var wrong: Result[Int, type_of(other)] = Capture[type_of(view)].consuming(fail[type_of(view)]).run(view)
    _ = wrong^
def main():
    var a: List[Int] = [3]
    var b: List[Int] = [7]
    check(a, b)
