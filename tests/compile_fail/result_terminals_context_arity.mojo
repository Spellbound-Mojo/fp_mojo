# error: no matching method in call to 'value_or'
from fp.data import Result, Err
from fp.functions import pipeline
def wrong() raises Int -> Int: raise 1
def main():
    _ = pipeline(Result[Int, String](Err(String("missing")))).raising[Int]().value_or(wrong)
