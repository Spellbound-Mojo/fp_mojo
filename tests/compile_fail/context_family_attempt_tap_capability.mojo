# error: no matching method in call to 'attempt_tap'
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.algebra import ResultFamily
from fp.algebra import ValidationFamily, StringMonoid
def observe(value: Result[Int,String]) -> Result[Int,String]: return Ok(0)
def main():
    _ = pipeline[ValidationFamily[StringMonoid]](Result[Int,String](Ok(1))).attempt_tap(observe)
