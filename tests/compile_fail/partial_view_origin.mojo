# error: origin
from fp.functions import pipeline, partial

def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    def keep(var prefix: View, value: Int) -> View: return prefix
    var view: View = Span(local)
    var callback = partial(keep, view)
    return pipeline(1).then(callback).get()
def main(): pass
