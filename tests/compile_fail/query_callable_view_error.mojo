# error: cannot call function that may raise
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily, StringMonoid

def fail(value: Int) raises Int -> Optional[String]: raise value

def main() raises String:
    var chain = kleisli[OptionalFamily](fail)
    _ = pipeline(List[Int]([1, 2])).raising[String]().fold_map_effect[StringMonoid](chain).get()
