# error: constraint
from fp.data import Result,Ok,Err
from fp.callables import mut_ref
from result_fold_receiver_support import Handler,Bare
from fp.callables import BorrowSignature
def shared(value:Int)->String: return String(value)
def main():
    var callback=BorrowSignature[Int,String].capture(shared)
    _=Result[Int,Int](Ok(1)).fold(callback,Handler(2,0))
