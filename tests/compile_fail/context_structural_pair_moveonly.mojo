# error: violated constraint
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import ValidationFamily, ListMonoid
from fp.callables import Unary
@fieldwise_init
struct Owned(Movable):
    var id:Int
def main(): _ = pipeline(List[Int]([1])).tuple_left(Owned(2)).get()
