# error: no matching method in call to 'attempt_tap'
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.algebra import ResultFamily
def observe(value: Result[Int,String]) -> Result[Int,String]: return Ok(0)
def main():
    _ = pipeline[ResultFamily[String]](Result[Int,Int](Ok(1))).attempt_tap(observe)
