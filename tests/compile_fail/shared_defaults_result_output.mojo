# error: no matching method
from fp.data import Result,Ok,Err
from fp.functions import pipeline
from shared_defaults_support import Factory
def main():
    var factory=Factory(String("bad"))
    _=Result[Int,Int](Err(1)).get_or_else(factory)
