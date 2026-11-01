# error: use of uninitialized value
from fp.data import Result, Ok, Err
def on_ok(var value: String) -> Result[String, String]: return Ok(value^)
def on_err(var error: String) -> Result[String, String]: return Err(error^)
def main():
    var value = Result[String, String](Ok(String("owned")))
    _ = value^.redeem_with(on_ok, on_err)
    _ = value^
