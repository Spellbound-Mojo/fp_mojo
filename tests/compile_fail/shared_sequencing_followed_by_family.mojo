# error: no matching method
from fp.data import Result,Ok
from fp.functions import pipeline
from shared_sequencing_support import Maker
def main():
    var factory=Maker(Optional(7))
    _=pipeline(List[Int]([1,2])).followed_by(factory)
