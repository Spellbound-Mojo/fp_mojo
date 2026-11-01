# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader
from fp.algebra import ValidationFamily, ListMonoid
from fp.data import Result, Ok
def wrong()->Optional[Int]:return Optional(1)
def main():_=pipeline(List[Int]([1])).before(wrong).get()
