# error: no matching method
# The callbacks fit Result[Int, String]; only the source carrier is unsupported.
from fp.functions import pipeline
from fp.data import Result, Ok

def first(value:String) -> Int: return 1

def main():
    _ = pipeline(List[Int]([1])).tap_err(first).get()
