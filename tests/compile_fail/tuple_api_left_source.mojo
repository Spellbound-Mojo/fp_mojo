# error: violated constraint
from algebra_support.tuple_contracts import attached_left
from fp.algebra import OptionalFamily
from fp.data import Result, Ok
def main():
    _ = attached_left[OptionalFamily](Result[Int, Int](Ok(1)), 3)
