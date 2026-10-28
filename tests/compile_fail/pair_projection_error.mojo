# error: cannot call function that may raise
from fp.functions import first
def fail(var value: Int) raises Int -> Int: raise value
def main(): _ = first[String](fail)((1, String("id")))
