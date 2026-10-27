# error: no matching method in call to 'value_or'
from fp.data import Result, Err
def wrong(mut error: String) -> Int: return error.byte_length()
def main():
    var source = Result[Int, String](Err(String("missing")))
    _ = source^.value_or(wrong)
