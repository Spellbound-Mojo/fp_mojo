# error: no matching method in call to 'fold_owned'
from fp.data import Result,Ok
from result_fold_receiver_support import Shared
def bad(value:Int)->String: return String(value)
def main():
    _=Result[Int,Int](Ok(1)).fold_owned(bad,Shared(0))
