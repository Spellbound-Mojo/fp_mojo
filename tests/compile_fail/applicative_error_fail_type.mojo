# error: cannot be converted
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import piped
from fp.data import Result, Ok, Err
def main():
    _ = fail[ResultFamily[String], Int](9)
