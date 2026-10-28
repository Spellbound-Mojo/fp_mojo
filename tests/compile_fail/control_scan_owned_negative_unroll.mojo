# error: control: unroll must be nonnegative
from fp.control import scan, ScanError, ScanLengthError
from fluent_fold_support import Step,Once,Bare
def main() raises:
    _=scan[unroll=-1](Step[Tuple[Int,Int]]((0,0)),0,List[Int]())
