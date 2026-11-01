# error: no matching method
from fp.data import Result, Ok
def next_value() -> Result[Int, Int]: return Ok(1)
def main():
    _ = Result[Int, String](Ok(1)).followed_by(next_value)
