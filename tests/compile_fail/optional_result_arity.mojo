# error: no matching
from fp.functions import pipeline
from fp.data import Result, Ok
def factory(value: Int) -> String: return String(value)
def main():
    _ = pipeline(Optional(1)).to_result(factory)
