# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import partial
from fp.iteration import find_map

def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> Optional[Span[Int, o]]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    var view: View = Span(local)
    def keep(size: Int, value: View) -> Optional[View]:
        if len(value) >= size: return Optional(value)
        return None
    var project = partial(keep, 1)
    var values: List[View] = [view]
    return find_map(project, values^)
def main(): pass
