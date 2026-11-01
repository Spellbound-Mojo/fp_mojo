# error: constraint
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import pipeline
from fp.data import Result, Ok, Err
def restore(var error: String) -> String: return error^
def main():
    _ = pipeline[ResultFamily[String]](fail[ResultFamily[String], Int](String("bad"))).recover(restore).get()
