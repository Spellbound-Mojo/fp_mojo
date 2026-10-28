# error: cannot implicitly convert
from fp.data import ok
from fp.functions import pipeline

def wrong(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var local: List[Int] = [1, 2]
    var view = Span(local)
    comptime View = type_of(view)
    def keep(value: View) -> View: return value
    return pipeline(ok[View](view)).fold(keep, keep)
def main(): _ = wrong([1])
