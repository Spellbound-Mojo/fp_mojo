# error: constraint
from fp.callables import invoke_borrowed_once
from fp.data import Result, Ok, Err
from result_fold_receiver_support import Handler, Bare
def rejected() raises Int:
    _ = Result[Int,Int](Ok(1)).fold(Handler[Int,Int](2,0),Handler[Int,String](2,0))
def main(): pass
