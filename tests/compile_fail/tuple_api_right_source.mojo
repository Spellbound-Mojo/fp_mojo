# error: violated constraint
from algebra_support.tuple_contracts import attached_right
from fp.algebra import OptionalFamily
from fp.data import Result, Ok
def main():
    _ = attached_right[OptionalFamily](Result[Int, Int](Ok(1)), 3)
