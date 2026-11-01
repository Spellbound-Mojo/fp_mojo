# error: constraint failed
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
def source(x:Int) raises Int -> Optional[Int]: return Optional(x)
def other(x:Int) raises String -> Optional[Int]: return Optional(x)
def main():
    try:
        _ = kleisli[OptionalFamily](source).then(other).call_once(1)
    except: pass
