# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
def main(): _ = pipeline(List[Result[Int,Int]]([Result[Int,Int](Ok(1))])).sequence_void[ResultFamily[String]]().get()
