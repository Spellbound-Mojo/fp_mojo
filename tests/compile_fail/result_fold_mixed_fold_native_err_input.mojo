# error: no matching method in call to 'fold'
from fp.data import Result,Ok
from result_fold_receiver_support import Shared
def bad(value:String)->Int: return 1
def main():
    _=Result[Int,Int](Ok(1)).fold(Shared(0),bad)
