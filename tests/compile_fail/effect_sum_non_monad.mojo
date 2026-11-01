# error: no matching
from fp.functions import pipeline
from fp.algebra import ValidationFamily, ListMonoid
from fp.data import Result, Ok
def project(var x: Int) -> Result[Int, List[String]]: return Ok(x)
def main() raises:
    _ = pipeline(List[Int]([1])).sum_by_effect[ValidationFamily[ListMonoid[String]]](project)
