# error: no matching method in call to 'get_or_else'
from fp.data import Result, Err
from fp.functions import pipeline
def main():
    var n = 1
    def wrong() raises Int {n} -> Int: raise n
    _ = pipeline(Result[Int, String](Err(String("missing")))).raising[String]().get_or_else(wrong)
