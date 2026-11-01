# error: use of uninitialized value
from fp.data import Result, Ok
def main():
    var source = Result[String, Int](Ok(String("value")))
    _ = source^.to_optional()
    _ = source.is_ok()
