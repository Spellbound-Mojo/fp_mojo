# error: no matching method
from fp.data import Result,Ok,Err
from fp.functions import pipeline
from shared_defaults_support import Factory
def main():
    var factory=Factory(String("bad"))
    _=pipeline(Optional[Int]()).get_or_else(factory)
