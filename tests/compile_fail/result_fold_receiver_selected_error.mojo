# error: constraint
from fp.callables import invoke_borrowed_once
from fp.data import Result, Ok, Err
from result_fold_receiver_support import Handler, Bare
def main() raises:
    _ = invoke_borrowed_once[Error](1,Handler[Int,Int](2,0))
