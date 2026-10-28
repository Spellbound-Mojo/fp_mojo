# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import partial
from fp.iteration import collect_fold
from fp.algebra import ListMonoid

def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> List[Span[Int, o]]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    var view: View = Span(local)
    def select(size: Int, value: View) -> Optional[List[View]]:
        if len(value) >= size: return Optional(List[View]([value]))
        return None
    var project = partial(select, 1)
    var values: List[View] = [view]
    return collect_fold[ListMonoid[View]](project, values^)
def main(): pass
