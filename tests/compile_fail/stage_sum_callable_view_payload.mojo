# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily

def text(value: Int) -> Optional[String]: return Optional(String(value))
def main():
    var chain = kleisli[OptionalFamily](text)
    _ = pipeline(List[Int]([1, 2])).sum_by_effect(chain).get()
