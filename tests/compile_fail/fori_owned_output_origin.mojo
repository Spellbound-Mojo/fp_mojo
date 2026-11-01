# error: cannot implicitly convert
from fp.control import fori_loop
from fluent_fold_support import Step, Once, Bare
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int,o]:
    var local: List[Int] = [1]
    var view = Span[Int,ImmOrigin(origin_of(local))](local)
    return fori_loop(0,1,Step[type_of(view),Never,Int,type_of(view)](view),view)
def main(): pass
