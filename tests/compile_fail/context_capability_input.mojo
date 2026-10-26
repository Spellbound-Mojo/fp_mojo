# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader
from fp.algebra import ValidationFamily, ListMonoid
from fp.data import Result, Ok
def wrong(x:String)->List[Int]:return List[Int]()
def main():_=pipeline(List[Int]([1])).flat_pair_with(wrong).get()
