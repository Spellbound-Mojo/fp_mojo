# error: use of uninitialized value
from fp.data import Result, Ok

def main():
    var source = Result[Int, Int](Ok(1))
    _ = source^.void()
    print(source.is_ok())
