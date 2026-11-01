# error: violated constraint
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import ValidationFamily, ListMonoid
from fp.callables import Unary
def main(): _ = pipeline(Optional(1)).ap(Optional(2)).get()
