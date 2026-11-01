# error: no matching method in call to 'map_err'
from fp.functions import pipeline
from fp.algebra import ResultFamily, ValidationFamily, StringMonoid, IdentityFamily
from fp.data import Result, Ok, Err
def size(var error: String) -> Int: return error.byte_length()
def main():
    _ = pipeline[ResultFamily[String]](Result[Int,Int](Ok(1))).map_err(size)
