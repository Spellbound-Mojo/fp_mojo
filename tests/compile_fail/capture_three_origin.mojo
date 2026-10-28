# error: cannot implicitly convert
# error: origin_of(other)
from fp.data import Capture, Result

def wrong(owner: List[Int], other: List[Int]) -> Result[Span[Int, origin_of(other)], Never]:
    var view = Span(owner)
    comptime View = type_of(view)
    var state = 0
    var label = String("view")
    def callback(text: String, mut count: Int, var value: View) -> View: return value
    return Capture().borrow(label).mutable(state).take(view).run(callback)

def main():
    _ = wrong(List[Int]([1]), List[Int]([2]))
