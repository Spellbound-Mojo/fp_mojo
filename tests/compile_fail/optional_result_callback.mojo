# error: no matching
from fp.functions import pipeline
from fp.data import Result, Ok

def main():
    _ = pipeline(Optional(1)).to_result(3)
