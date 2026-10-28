# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import pipeline, partial
from fp.data import ok

def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    var view: View = Span(local)
    def keep(var prefix: View, value: Int) -> View: return prefix
    var callback = partial(keep, view)
    return pipeline(ok[Int](2)).fold(callback, callback)
def main(): pass
