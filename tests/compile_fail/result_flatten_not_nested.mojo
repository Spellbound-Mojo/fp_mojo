# error: invalid call to 'flatten'
from fp.data import Result,Ok,Err
def main():
    _=Result[Int,Int](Ok(1)).flatten()
