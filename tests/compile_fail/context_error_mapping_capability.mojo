# error: no matching method in call to 'map_err'
from fp.functions import pipeline
from fp.algebra import ResultFamily, ValidationFamily, StringMonoid, IdentityFamily
from fp.data import Result, Ok, Err
from outcome_admission_support import Restricted
def size(var error: String) -> Int: return error.byte_length()
def main():
    _ = pipeline[Restricted[True,True,True,True]](Result[Int,String](Err(String("old")))).map_err(size)
