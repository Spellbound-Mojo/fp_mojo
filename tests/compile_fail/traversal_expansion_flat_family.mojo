# error: constraint
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ListFamily
from fp.data import Result, Ok
def wrong(value: Int) -> Optional[Result[Int, Int]]: return Optional(Result[Int, Int](Ok(value)))
def main():
    _ = pipeline(Result[Int, String](Ok(1))).flat_traverse[OptionalFamily](wrong)
