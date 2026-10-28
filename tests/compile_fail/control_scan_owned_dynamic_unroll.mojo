# error: control: full unrolling requires static bounds
from fp.control import scan, ScanError, ScanLengthError
from fluent_fold_support import Step,Once,Bare
def main() raises:
    _=scan[unroll=0](Step[Tuple[Int,Int]]((0,0)),0,List[Int]())
