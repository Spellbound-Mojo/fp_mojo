# error: no matching method in call to 'fold_owned'
from fp.data import Result,Ok
from result_fold_receiver_support import Shared
def bad(mut value:Int)->Int: return value
def main():
    _=Result[Int,Int](Ok(1)).fold_owned(Shared(0),bad)
