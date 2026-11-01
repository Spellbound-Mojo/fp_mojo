# error: no matching method in call to 'map_both'
from fp.functions import pipeline
from fp.algebra import ResultFamily, ValidationFamily, StringMonoid, IdentityFamily
from fp.data import Result, Ok, Err
from error_mapping_support import Probe
def size(var error: String) -> Int: return error.byte_length()
def show(var value: Int) -> String: return String(value)
def main():
    _ = pipeline[Probe[String,1]](Result[Int,String](Err(String("old")))).map_both(show,size)
