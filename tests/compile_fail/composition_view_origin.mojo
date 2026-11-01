# error: origin
from fp.functions import pipeline, flow

def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> List[Span[Int, o]]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    def keep(var value: View) -> View: return value
    var chain = flow(keep, keep)
    var view: View = Span(local)
    return pipeline(List[View]([view])).map(chain).get()
def main(): pass
