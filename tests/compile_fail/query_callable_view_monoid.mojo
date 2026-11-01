# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily, StringMonoid

def select(value: Int) -> Optional[Int]: return Optional(value)
def main():
    var chain = kleisli[OptionalFamily](select)
    _ = pipeline(List[Int]([1, 2])).fold_map_effect[StringMonoid](chain).get()
