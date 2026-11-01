# error: constraint
from fp.callables import invoke_borrowed_once
from fp.data import Result, Ok, Err
from result_fold_receiver_support import Handler, Bare
def main():
    _ = invoke_borrowed_once[Never](1,Handler[Int,Never,String](2,0))
