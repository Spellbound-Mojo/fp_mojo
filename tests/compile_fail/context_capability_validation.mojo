# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader
from fp.algebra import ValidationFamily, ListMonoid
from fp.data import Result, Ok
def next(x:Int)->Result[Int,List[Int]]:return Ok(x)
def main():_=pipeline[ValidationFamily[ListMonoid[Int]]](Result[Int,List[Int]](Ok(1))).flat_tap(next).get()
