# error: no matching method in call to 'redeem_with'
from fp.data import Result, Ok
def on_ok(value: Int) -> Int: return value
def on_err(var error: String) -> Int: return 0
def main(): _ = Result[Int, String](Ok(1)).redeem_with(on_ok, on_err)
