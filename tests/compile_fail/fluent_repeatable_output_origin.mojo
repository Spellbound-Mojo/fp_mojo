# error: cannot implicitly convert
from fp.functions import pipeline, piped
from fp.data import ControlFlow, Continue
from fluent_fold_support import Step, Once, Bare
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int,o]:
    var local: List[Int] = [1]
    var view = Span[Int,ImmOrigin(origin_of(local))](local)
    return pipeline[Int]([1]).fold_left(Step[type_of(view),Never,type_of(view)](view),view).get()
def main(): pass
