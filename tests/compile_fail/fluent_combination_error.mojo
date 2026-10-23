from fp.functions import piped
# error: no matching method in call to 'product'
from fp.data import Result, Ok
def main():
    _ = piped(Result[Int, String](Ok(1))).product(Result[Int, Int](Ok(2))).get()
