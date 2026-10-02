# error: no matching method in call to 'fold'
from fp.data import Result, Ok

def number(value: Int) raises Int -> Int:
    raise 1

def text(value: Int) raises String -> Int:
    raise String("different")

def main() raises Int:
    var value = Result[Int, Int](Ok(1))
    _ = value.fold(number, text)
