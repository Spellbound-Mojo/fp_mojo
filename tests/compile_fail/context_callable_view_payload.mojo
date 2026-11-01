# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily

def step(value: String) -> Optional[Int]: return Optional(value.byte_length())
def main():
    var chain = kleisli[OptionalFamily](step)
    _ = pipeline(List[Int]([1, 2])).map(chain).get()
