# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily

def select(value: String) -> Optional[Int]: return Optional(value.byte_length())
def main():
    var chain = kleisli[OptionalFamily](select)
    _ = pipeline(List[Int]([1, 2])).find_map(chain).get()
