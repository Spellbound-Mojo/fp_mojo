# error: violated constraint
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import StringMonoid
def main(): _ = pipeline(List[Result[Int,List[String]]]([Result[Int,List[String]](Ok(1))])).par_sequence[StringMonoid]().get()
