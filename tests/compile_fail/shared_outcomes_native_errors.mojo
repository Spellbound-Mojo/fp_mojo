# error: no matching method in call to 'redeem'
from fp.algebra import ResultFamily
from fp.functions import pipeline
from fp.data import Result, Ok
def left(var value: Int) raises Int -> Int: return value
def right(var error: String) raises String -> Int: return 0
def main() raises:
    try:
        _ = pipeline(Result[Int, String](Ok(1))).redeem[ResultFamily[String]](left, right)
    except error: pass
