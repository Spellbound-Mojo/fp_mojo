# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily, ResultFamily

def step(value: Int) -> Optional[Int]: return Optional(value)
def main():
    var chain = kleisli[OptionalFamily](step)
    _ = pipeline(List[Int]([1, 2])).traverse[ResultFamily[String]](chain).get()
