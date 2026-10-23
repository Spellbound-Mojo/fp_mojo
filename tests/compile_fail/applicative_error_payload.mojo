# error: constraint
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import piped
from fp.data import Result, Ok, Err
def restore(var error: String) -> String: return error^
def main():
    _ = piped(fail[ResultFamily[String], Int](String("bad"))).recover[ResultFamily[String]](restore).get()
