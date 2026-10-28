# error: cannot implicitly convert
from fp.control import scan, ScanError, ScanLengthError
from fluent_fold_support import Step,Once,Bare
def wrong[o:ImmOrigin](ref[o] owner:List[Int]) raises ScanLengthError -> Tuple[Int,List[Span[Int,o]]]:
    var local:List[Int]=[1]
    var view=Span[Int,ImmOrigin(origin_of(local))](local)
    return scan(Step[Tuple[Int,type_of(view)]]((0,view)),0,List[Int]())
def main() raises:
    var owner:List[Int]=[0]
    _=wrong(owner)
