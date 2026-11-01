# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily

def check(value: String) -> Optional[Int]: return Optional(value.byte_length())
def main():
    var chain = kleisli[OptionalFamily](check)
    _ = pipeline(1).then(chain).get()
