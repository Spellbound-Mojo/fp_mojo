# error: no matching
from fp.functions import pipeline
from fp.data import Result, Ok
def factory() -> String: return String("bad")
def main():
    _ = pipeline(Result[Int, String](Ok(1))).to_result(factory)
