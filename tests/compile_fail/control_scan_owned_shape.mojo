# error: no matching function in call to 'scan'
from fp.control import scan
from fluent_fold_support import Step,Once,Bare
def main() raises:
    _ = scan(Step[Int](1),0,List[Int]())
