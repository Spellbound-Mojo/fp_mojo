# error: constraint
from fp.data import Result, Ok
def left() -> Result[Int,String]: return Ok(1)
def right() -> Result[Int,Int]: return Ok(2)
def main(): _ = Result[Bool,String](Ok(True)).if_effect(left,right)
