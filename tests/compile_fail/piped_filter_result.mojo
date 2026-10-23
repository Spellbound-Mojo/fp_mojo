# error: no matching method in call to 'filter'
from fp.functions import piped
from fp.data import Result, Ok
def select(x: Int) -> Bool: return x > 0
def main():
    var xs = Result[Int, String](Ok(1))
    _ = piped(xs^).filter(select).get()
