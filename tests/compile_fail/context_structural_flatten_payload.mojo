# error: invalid call to 'flatten': violated constraint
# error: CarrierCompatible
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import ValidationFamily,ListMonoid
from fp.callables import Unary
def main(): _ = pipeline(List[Int]([1])).flatten().get()
