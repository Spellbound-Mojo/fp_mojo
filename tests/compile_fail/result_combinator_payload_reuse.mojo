# error: use of uninitialized value
from fp.data import Result, Ok
def project(value: Int) -> Result[Int, String]: return Ok(value)
def main():
    var value = Result[Int, String](Ok(1))
    _ = value^.flat_tap(project)
    _ = value^
