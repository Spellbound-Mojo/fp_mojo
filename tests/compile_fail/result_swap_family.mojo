# error: no matching
from fp.data import Result, Err
from fp.functions import pipeline
def wrong(var value: String) -> Result[Int, String]: return Err(value^)
def main():
    _ = pipeline(Result[Int, String](Err(String("bad")))).swap().flat_map(wrong)
