# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader
from fp.algebra import ValidationFamily, ListMonoid
from fp.data import Result, Ok
def wrong(x:Int)->Optional[Int]:return Optional(x)
def main():_=pipeline(List[Int]([1])).flat_tap(wrong).get()
