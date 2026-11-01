# error: use of uninitialized value
from fp.data import Result,Ok
from fp.functions import pipeline
from shared_defaults_support import Factory
def main():
    var factory=Factory(1)
    _=pipeline(Result[Int,Int](Ok(1))).get_or_else(factory^)
    _=factory.value
