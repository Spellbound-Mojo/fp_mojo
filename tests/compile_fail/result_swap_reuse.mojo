# error: use of uninitialized value
from fp.data import Result, Ok
def main():
    var result = Result[Int, String](Ok(1))
    _ = result^.swap()
    _ = result^.swap()
