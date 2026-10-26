# error: List callback required
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
def main(): _ = pipeline(List[Optional[Optional[Int]]]([Optional(Optional(1))])).flat_sequence[OptionalFamily]().get()
