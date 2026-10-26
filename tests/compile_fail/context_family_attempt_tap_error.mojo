# error: no matching method in call to 'attempt_tap'
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.algebra import ResultFamily
def main():
    var code=1
    def observe(value: Result[Int,String]) raises Int {code} -> Result[Int,String]: raise code
    _ = pipeline(Result[Int,String](Ok(1))).raising[String]().attempt_tap(observe)
