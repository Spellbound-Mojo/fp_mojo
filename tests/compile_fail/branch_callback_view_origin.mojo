# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import partial
from fp.iteration import partition_map, Unbounded
from fp.data import Result, Ok
from std.iter import next

def wrong[o: ImmOrigin](ref[o] outer: List[Int]) raises -> Span[Int, o]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    var view: View = Span(local)
    def keep(size: Int, value: View) -> Result[View, Int]:
        _ = size
        return Ok(value)
    var classifier = partial(keep, 1)
    var values: List[View] = [view]
    var branches = partition_map(classifier, values^, buffer=Unbounded())
    return next(branches[0])
def main(): pass
