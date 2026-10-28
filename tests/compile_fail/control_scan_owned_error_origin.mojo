# error: constraint failed: Type does not exist in Variant.
from fp.control import scan, ScanError, ScanLengthError
from fluent_fold_support import Step,Once,Bare
def wrong[o:ImmOrigin](ref[o] owner:String) raises ScanError[Pointer[String,o]] -> Tuple[Int,List[Int]]:
    var local=String("local")
    return scan(Step[Tuple[Int,Int],Pointer[String,ImmOrigin(origin_of(local))]]((0,0)),0,List[Int]())
def main() raises:
    var owner=String("owner")
    try: _=wrong(owner)
    except: pass
