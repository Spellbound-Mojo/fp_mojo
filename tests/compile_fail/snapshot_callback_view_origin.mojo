# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import partial
from fp.iteration import iterated
def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> List[Span[Int, o]]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    var view: View = Span(local)
    def step(preferred: View, carry: View, item: Int) -> View:
        _ = carry
        _ = item
        return preferred
    var callback = partial(step, view)
    return iterated(range(2)).scan_left(callback, view).collect_list()
def main(): pass
