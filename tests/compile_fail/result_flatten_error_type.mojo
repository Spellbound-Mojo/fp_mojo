# error: invalid call to 'flatten'
from fp.data import Result,Ok,Err
def main():
    _=Result[Result[Int,String],Int](Ok(Result[Int,String](Ok(1)))).flatten()
