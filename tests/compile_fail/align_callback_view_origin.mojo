# error: cannot implicitly convert
# error: origin_of(local)
from fp.functions import as_unary
from fp.iteration import iterated
from fp.data import Ior
def wrong[o: ImmOrigin](ref[o] outer: List[Int]) -> List[Span[Int, o]]:
    var local: List[Int] = [1]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    var view: View = Span(local)
    def project(var value: Ior[Int, Int]) {view} -> View:
        _ = value^
        return view
    var callback = as_unary(project)
    return iterated(range(2)).align_with(range(3), callback).collect_list()
def main(): pass
