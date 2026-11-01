# error: no matching method in call to 'value_or'
from fp.data import Result, Err
def main():
    var n = 1
    def wrong(mut error: String) {n} -> Int: return n
    _ = Result[Int, String](Err(String("missing"))).value_or(wrong)
