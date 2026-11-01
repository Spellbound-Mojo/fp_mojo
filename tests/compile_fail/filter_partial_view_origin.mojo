# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import partial
from fp.iteration import iterated

def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> List[Span[Int, o]]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    var view: View = Span(local)
    def keep(size: Int, value: View) -> Bool: return len(value) >= size
    var predicate = partial(keep, 1)
    var source: List[View] = [view]
    return iterated(source^).filter(predicate).collect_list()
def main(): pass
