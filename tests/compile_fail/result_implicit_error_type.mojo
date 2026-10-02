# error: cannot implicitly convert 'Err[Int]' value to 'Result[Int, String]'
from fp.data import Result, Err

def parse() -> Result[Int, String]:
    return Err(3)

def main():
    _ = parse()
