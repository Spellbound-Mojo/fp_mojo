# error: cannot be converted
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import piped
from fp.data import Result, Ok, Err
from fp.algebra import OptionalFamily
def main():
    _ = fail[OptionalFamily, Int](1)
