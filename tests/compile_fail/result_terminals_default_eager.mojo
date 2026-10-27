# error: no matching method in call to 'get_or_else'
from fp.data import Result, Err
def main():
    var source = Result[Int, String](Err(String("missing")))
    _ = source^.get_or_else(42)
