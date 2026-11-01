# error: no matching method in call to 'redeem_with'
from fp.data import Result, Ok, Err
def on_ok(value: Int) -> Result[String, Int]: return Err(value)
def on_err(var error: String) -> Result[String, String]: return Err(error^)
def main(): _ = Result[Int, String](Ok(1)).redeem_with(on_ok, on_err)
