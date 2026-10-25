# error: no matching method
# The callbacks fit Result[Int, String]; only the source carrier is unsupported.
from fp.functions import pipeline
from fp.data import Result, Ok

def first(value:Result[Int,String]) -> Result[Int,String]: return Ok(1)

def main():
    _ = pipeline(Optional(1)).attempt_tap(first).get()
