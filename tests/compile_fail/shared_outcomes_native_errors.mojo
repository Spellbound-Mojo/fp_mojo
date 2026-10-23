# error: constraint
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def left(var value: Int) raises Int -> Int: return value
def right(var error: String) raises String -> Int: return 0
def main() raises:
    try:
        _ = piped(Result[Int, String](Ok(1))).redeem[ResultFamily[String]](left, right)
    except error: pass
