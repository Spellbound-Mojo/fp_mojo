# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import ResultFamily
from fp.data import Result, Err, Ok

def success(value: Int) -> Result[Int, String]: return Ok(value)
def failure(var reason: String) -> Result[Int, Int]: return Err(reason.byte_length())
def main():
    var on_ok = kleisli[ResultFamily[String]](success)
    var on_err = kleisli[ResultFamily[Int]](failure)
    _ = pipeline(Result[Int, String](Err(String("bad")))).redeem_with(on_ok, on_err).get()
