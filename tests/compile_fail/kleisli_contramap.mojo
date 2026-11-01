# error: constraint
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
def source(x:Int) -> Optional[Int]: return Optional(x)
def before(x:Int) -> String: return String(x)
def main():
    _ = kleisli[OptionalFamily](source).contramap(before).call_once(1)
