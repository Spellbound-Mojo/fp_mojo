# error: no matching
from fp.functions import pipeline
from fp.algebra import ValidationFamily, ListMonoid
from fp.data import Result, Ok
def step(var a: Int, var b: Int) -> Result[Int, List[String]]: return Ok(a + b)
def main():
    _ = pipeline(List[Int]([1])).fold_effect(0).run[ValidationFamily[ListMonoid[String]]](step)
