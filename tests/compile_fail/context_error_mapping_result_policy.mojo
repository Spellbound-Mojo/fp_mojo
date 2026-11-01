# error: no matching method in call to 'map_err'
from fp.functions import pipeline
from fp.algebra import ResultFamily, ValidationFamily, StringMonoid, IdentityFamily
from fp.data import Result, Ok, Err
def keep(var error: String) -> String: return error^
def main():
    _ = pipeline(Result[Int,String](Err(String("old")))).map_err[Target=ValidationFamily[StringMonoid]](keep)
