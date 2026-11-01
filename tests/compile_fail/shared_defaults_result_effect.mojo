# error: cannot call function that may raise
from fp.data import Result,Ok,Err
from fp.functions import pipeline
from shared_defaults_support import Factory
def main():
    var factory=Factory[Int,Int](1)
    _=Result[Int,Int](Err(1)).get_or_else(factory)
