# error: no matching
from fp.data import Result, Err
from fp.functions import pipeline
def fail(var value: String) raises String -> Int: raise value^
def main():
    _ = pipeline(Result[Int, String](Err(String("bad")))).raising[Int]().swap().map(fail)
