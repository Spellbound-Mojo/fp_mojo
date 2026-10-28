# error: scan: static_length must be nonnegative or omitted
from fp.control import scan, ScanError, ScanLengthError
from fluent_fold_support import Step,Once,Bare
def main() raises:
    _=scan[static_length=-2](Step[Tuple[Int,Int]]((0,0)),0,List[Int]())
