# error: no matching method
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
def yes(error: String) -> Bool: return True
def wrong(var error: String) -> Result[Int, Int]: return Ok(0)
def main():
    _ = pipeline(fail[ResultFamily[String], Int](String("bad"))).or_else_if[ResultFamily[String]](yes, wrong).get()
