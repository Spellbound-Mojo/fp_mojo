# error: origin
from fp.functions import pipeline, partial
from fp.data import ok

def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    var view = Span(local)
    comptime View = type_of(view)
    def keep(var prefix: View, value: Int) -> View: return prefix
    var callback = partial(keep, view)
    return pipeline(ok[Int](2)).fold(callback, callback)
def main(): pass
