# error: invalid call to 'sequence_filter': violated constraint
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
def main(): _ = pipeline(List[Optional[Int]]([Optional(1)])).sequence_filter[OptionalFamily]().get()
