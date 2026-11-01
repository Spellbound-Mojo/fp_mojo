# error: invalid call to 'flatten'
from fp.data import Result,Ok,Err
def main():
    _=Result[Optional[Int],Int](Ok(Optional(1))).flatten()
