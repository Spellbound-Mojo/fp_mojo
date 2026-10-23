# error: no matching method in call to 'sum'
from fp.functions import piped
from fp.data import Result, Ok
def main():
    _ = piped(Result[Int, String](Ok(1))).sum().get()
