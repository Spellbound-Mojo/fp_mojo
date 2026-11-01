# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import partial
from fp.iteration import iterated
def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> List[Span[Int, o]]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    var view: View = Span(local)
    def choose(bias: Int, first: View, second: View) -> View:
        _ = bias
        _ = second
        return first
    var callback = partial(choose, 0)
    var left: List[View] = [view]
    var right: List[View] = [view]
    return iterated(left^).zip_with(right^, callback).collect_list()
def main(): pass
