# error: no matching method
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.effects import Reader,run
from fp.callables import OnceThunk
def good() -> Optional[Int]: return Optional(1)
def bad()->Result[Int,Int]: return Ok(1)
def good_result()->Result[Int,String]: return Ok(2)
def main(): _ = pipeline(Result[Bool,String](Ok(True))).if_effect(good_result,bad).get()
