# error: cannot implicitly convert
from fp.data import Result, Err

def wrong() -> Result[String, String]:
    return Result[Int, Int](Err(7)).fill(String("unused"))

def main():
    _ = wrong()
