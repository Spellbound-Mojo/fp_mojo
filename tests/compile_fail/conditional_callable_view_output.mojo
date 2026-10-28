# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import ResultFamily
from fp.data import Result, Err, Ok

def choose(reason: String) -> Bool: return True
def retry(var reason: String) -> Result[String, String]: return Ok(reason^)

def main():
    var handler = kleisli[ResultFamily[String]](retry)
    _ = pipeline(Result[Int, String](Err(String("bad")))).or_else_if(choose, handler).get()
