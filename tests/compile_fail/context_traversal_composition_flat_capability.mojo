# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(var value: Int) -> Optional[Result[Int,List[String]]]: return Optional(Result[Int,List[String]](Ok(value)))
def main():
    _ = pipeline[ValidationFamily[ListMonoid[String]]](Result[Int,List[String]](Ok(1))).flat_traverse[OptionalFamily](callback).get()
