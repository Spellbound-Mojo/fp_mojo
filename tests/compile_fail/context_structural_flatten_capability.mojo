# error: violated constraint
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import ValidationFamily,ListMonoid
from fp.callables import Unary
def main(): _ = pipeline[ValidationFamily[ListMonoid[String]]](Result[Result[Int,List[String]],List[String]](Err(List[String]()))).flatten().get()
