# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import ResultFamily
from fp.data import Result, Err, Ok

def choose(reason: String) -> Bool: return True
def retry(var reason: String) -> Result[Int, Int]: return Ok(1)

def main():
    var handler = kleisli[ResultFamily[Int]](retry)
    _ = pipeline(Result[Int, String](Err(String("bad")))).or_else_if(choose, handler).get()
