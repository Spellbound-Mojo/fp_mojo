# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from fp.data import Result, Ok
def callback(value: Int) -> Optional[Bool]: return Optional(True)
def main(): _ = pipeline(Result[Int,String](Ok(1))).filter_effect[OptionalFamily](callback).get()
