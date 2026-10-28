# error: both handlers must implement a receiver mode
from fp.callables import invoke_borrowed_once
from fp.data import Result, Ok, Err
from result_fold_receiver_support import Handler, Bare
def main():
    _ = Result[Int,Int](Ok(1)).fold(Handler(2,0),Bare())
