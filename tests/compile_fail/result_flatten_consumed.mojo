# error: use of uninitialized value 'nested'
from fp.data import Result,Ok,Err
def main():
    var nested=Result[Result[Int,Int],Int](Ok(Result[Int,Int](Ok(1))))
    _=nested^.flatten()
    _=nested^.flatten()
