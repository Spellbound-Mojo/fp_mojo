# error: no matching method
from fp.functions import piped
from fp.data import Result, Ok
def branch() -> Result[Int,String]: return Ok(1)
def main(): _ = piped(Result[Int,String](Ok(1))).if_effect(branch,branch)
