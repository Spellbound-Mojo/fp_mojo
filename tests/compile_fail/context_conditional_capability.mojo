# error: no matching method
from fp.functions import pipeline
from fp.algebra import ValidationFamily,ListMonoid
from fp.data import Result,Ok
def factory()->Result[Int,List[String]]: return Ok(1)
def main():
    _ = pipeline[ValidationFamily[ListMonoid[String]]](Result[Bool,List[String]](Ok(True))).if_effect(factory,factory).get()
