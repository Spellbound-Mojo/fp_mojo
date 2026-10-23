# error: no matching method
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def left(var value: Int) -> Int: return value
def right(var error: String) -> String: return error^
def main(): _ = piped(Result[Int, String](Ok(1))).redeem[ResultFamily[String]](left, right)
