# error: origin_of(local)
from fp._binding_architecture import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int
from fp.data import Result
def identity[T: Movable & Deinitable](var value: T) -> T: return value^
def check(anchor: List[Int], local: List[Int]):
    var view = Span(local)
    var other = Span(anchor)
    var wrong: Result[type_of(other), Never] = Capture[Never].consuming(identity[type_of(view)]).run(view)
    _ = wrong^
def main():
    var a: List[Int] = [3]
    var b: List[Int] = [7]
    check(a, b)
