# error: use of uninitialized value 'inactive'
from fp.callables import invoke_borrowed_once
from fp.data import Result, Ok, Err
from result_fold_receiver_support import Handler, Bare
def main():
    var inactive = Handler(2,0)
    _ = Result[Int,Int](Ok(1)).fold_once(Handler(2,0),inactive^)
    print(inactive.calls)
