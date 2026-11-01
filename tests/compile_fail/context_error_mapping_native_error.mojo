# error: no matching method in call to 'map_err'
from fp.functions import pipeline
from fp.algebra import ResultFamily, ValidationFamily, StringMonoid, IdentityFamily
from fp.data import Result, Ok, Err
def main():
    var code = 7
    def size(var error: String) raises Int {code} -> Int: raise code
    _ = pipeline(Result[Int,String](Err(String("old")))).raising[String]().map_err(size)
