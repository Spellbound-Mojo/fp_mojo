# error: callback must retain the success type
from fp.functions import kleisli
from fp.algebra import ResultFamily
from fp.data import Result, Err, Ok

def retry(var reason: String) -> Result[String, String]: return Ok(reason^)

def main():
    var handler = kleisli[ResultFamily[String]](retry)
    _ = Result[Int, String](Err(String("bad"))).or_else(handler)
