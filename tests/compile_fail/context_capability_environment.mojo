# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader
from fp.algebra import ValidationFamily, ListMonoid
from fp.data import Result, Ok
def wrong()->Reader[String].Pure[Int]:return Reader[String].pure(1)
def main():_=pipeline[Reader[Int]](Reader[Int].pure(1)).followed_by(wrong).get()
