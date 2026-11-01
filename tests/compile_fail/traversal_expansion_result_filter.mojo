# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ListFamily
from fp.data import Result, Ok
def check(value: Int) -> Optional[Bool]: return Optional(True)
def main():
    _ = pipeline(Result[Int, String](Ok(1))).filter_effect[OptionalFamily](check)
