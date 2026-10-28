# error: use of uninitialized value
from fp.data import Result,Ok
from fp.functions import pipeline
from shared_defaults_support import Factory
def main():
    var factory=Factory(1)
    _=pipeline(Optional[Int](1)).to_result(factory^)
    _=factory.value
