# error: use of uninitialized value 'step'
from fp.control import scan, ScanError, ScanLengthError
from fluent_fold_support import Step,Once,Bare
def main() raises:
    var step=Step[Tuple[Int,Int]]((0,0))
    _=scan(step^,0,List[Int]())
    _=step.output
