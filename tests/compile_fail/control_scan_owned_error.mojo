# error: constraint failed: Type does not exist in Variant.
from fp.control import scan, ScanError, ScanLengthError
from fluent_fold_support import Step,Once,Bare
def wrong() raises ScanError[String]:
    _=scan(Step[Tuple[Int,Int],Int]((0,0)),0,List[Int]())
def main() raises:
    try: wrong()
    except: pass
