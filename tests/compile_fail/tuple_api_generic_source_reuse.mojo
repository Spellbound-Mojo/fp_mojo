# error: use of uninitialized value
from fp.data import Result, Ok, Err
from fp.algebra import ResultFamily
from algebra_support.tuple_contracts import attached_left, attached_right

def main():
    var source = Result[Int, Int](Ok(1))
    var value: List[Int] = [2]
    _ = attached_right[ResultFamily[Int]](source^, value^)
    print(source.is_ok())
