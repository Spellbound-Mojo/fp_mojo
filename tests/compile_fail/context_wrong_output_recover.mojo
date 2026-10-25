# error: no matching method
# The first callback returns an incompatible type; admission must reject it.
from fp.functions import pipeline
from fp.data import Result, Ok

def first(var value:String) -> String: return String("bad")

def main():
    _ = pipeline(Result[Int,String](Ok(1))).recover(first).get()
