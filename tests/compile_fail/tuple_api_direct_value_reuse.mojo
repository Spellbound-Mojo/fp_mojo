# error: use of uninitialized value
from fp.data import Result, Ok, Err

def main():
    var source = Result[Int, Int](Ok(1))
    var value: List[Int] = [2]
    _ = source^.tuple_right(value^)
    print(len(value))
