# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok

def check(value: Int) -> Result[Int, String]: return Ok(value)
def main():
    var chain = kleisli[ResultFamily[String]](check)
    _ = pipeline(List[Int]([1, 2])).sum_by_effect[OptionalFamily](chain).get()
