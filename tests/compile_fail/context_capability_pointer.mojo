# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader
from fp.algebra import ValidationFamily, ListMonoid
from fp.data import Result, Ok
def wrong()->Optional[Int]:return Optional(1)
def main():
    var f:def() thin ->Optional[Int]=wrong
    _=pipeline(List[Int]([1])).followed_by(f).get()
