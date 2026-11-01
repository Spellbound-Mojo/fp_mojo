# error: aliasing
from fp.data import Result,Ok,Err
from fp.callables import mut_ref
from result_fold_receiver_support import Handler,Bare
def main():
    var handler=Handler(2,0)
    _=Result[Int,Int](Ok(1)).fold(mut_ref(handler),mut_ref(handler))
