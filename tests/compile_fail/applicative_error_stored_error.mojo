# error: constraint
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import piped
from fp.data import Result, Ok, Err
def restore(var error: String) -> Result[Int, Int]: return Err(1)
def main():
    _ = piped(fail[ResultFamily[String], Int](String("bad"))).or_else[ResultFamily[String]](restore).get()
