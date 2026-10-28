# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import ResultFamily
from fp.data import Result, Ok

def step(value: Int) -> Result[Int, String]: return Ok(value)
def main():
    var chain = kleisli[ResultFamily[String]](step)
    _ = pipeline(List[Int]([1, 2])).traverse_filter(chain).get()
