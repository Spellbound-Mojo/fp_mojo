# error: violated constraint
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import ValidationFamily,ListMonoid
from fp.callables import Unary
def main(): _ = pipeline(Result[Result[Int,Int],String](Ok(Result[Int,Int](Ok(1))))).flatten().get()
