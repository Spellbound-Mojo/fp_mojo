# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import partial
from fp.iteration import iterated
def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> List[Span[Int, o]]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    var view: View = Span(local)
    def step(bias: Int, carry: Int, item: View) -> Tuple[Int, View]: return (carry + bias, item)
    var callback = partial(step, 0)
    var source: List[View] = [view]
    return iterated(source^).scan_map(callback, 0).collect_list()
def main(): pass
