# error: origin
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily

def bad[o: ImmOrigin](ref[o] outer: List[Int]) -> List[Span[Int, o]]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    def wrap(value: View) -> Optional[View]: return Optional(value)
    var chain = kleisli[OptionalFamily](wrap)
    var view: View = Span(local)
    return pipeline(List[View]([view])).filter_map(chain).get()

def main(): pass
