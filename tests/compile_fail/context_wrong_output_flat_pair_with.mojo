# error: no matching method
# The first callback returns an incompatible type; admission must reject it.
from fp.functions import pipeline
from fp.data import Result, Ok

def first(value:Int) -> Int: return 1

def main():
    _ = pipeline(Result[Int,String](Ok(1))).flat_pair_with(first).get()
