from fp.algebra import map, ResultFamily
# error: use of uninitialized value
from fp.data import Result, Ok
from result_once_support import Constant, Address

def main():
    var subject = Result[String,Int](Ok(String('moved')))
    _ = map[ResultFamily[type_of(subject).Error]](Constant[Int, Never, String](1), subject^)
    _ = subject^
