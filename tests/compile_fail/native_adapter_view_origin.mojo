# error: origin
from fp.functions import pipeline, as_unary

def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    var view = Span(local)
    comptime View = type_of(view)
    def keep(var value: Int) {view} -> View: return view
    var callback = as_unary(keep)
    return pipeline(1).then(callback).get()
def main(): pass
