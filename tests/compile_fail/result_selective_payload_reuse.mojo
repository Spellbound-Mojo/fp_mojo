# error: use of uninitialized value
from fp.data import Result, Err, Ok
def observe(error: String) -> Result[Int, String]: return Ok(0)
def main():
    var value = Result[String, String](Err(String("owned")))
    _ = value^.flat_tap_err(observe)
    _ = value^
