# error: no matching
from fp.functions import pipeline
from fp.algebra import ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(value: Int) -> Result[Bool, List[String]]: return Ok(True)
def main():
    _ = pipeline(List[Int]([1])).any_effect[ValidationFamily[ListMonoid[String]]](callback)
