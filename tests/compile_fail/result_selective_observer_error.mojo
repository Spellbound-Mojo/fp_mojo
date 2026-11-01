# error: no matching method
from fp.data import Result, Err
def observe(error: String) -> Result[Int, Int]: return Err(1)
def main():
    _ = Result[Int, String](Err(String("retry"))).flat_tap_err(observe)
