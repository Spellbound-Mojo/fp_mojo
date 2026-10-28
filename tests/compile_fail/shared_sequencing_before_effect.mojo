# error: cannot call function that may raise
from fp.data import Result,Ok
from fp.functions import pipeline
from shared_sequencing_support import Maker
def main():
    var factory=Maker[Result[Int,Int],Int](Result[Int,Int](Ok(7)))
    _=Result[Int,Int](Ok(1)).before(factory)
