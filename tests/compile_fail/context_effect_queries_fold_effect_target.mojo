# error: parameter 'J' has 'Monad' type
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(var acc: Int, var value: Int) -> Optional[Int]: return Optional(value)
def main(): _ = pipeline(List[Int]([1])).fold_effect[ValidationFamily[ListMonoid[String]]](0).run(callback).get()
