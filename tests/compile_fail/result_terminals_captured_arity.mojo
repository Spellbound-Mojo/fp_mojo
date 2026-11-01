# error: no matching method in call to 'get_or_else'
from fp.data import Result, Err
def main():
    var n = 1
    def wrong(value: Int) {n} -> Int: return n + value
    _ = Result[Int, String](Err(String("missing"))).get_or_else(wrong)
