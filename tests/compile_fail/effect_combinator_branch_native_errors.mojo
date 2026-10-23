from fp.functions import piped
# error: incompatible native errors
from fp.data import Result, Ok
def left() raises String -> Result[Int,String]: raise String("left")
def right() raises Int -> Result[Int,String]: raise 2
def main():
    try: _ = piped(Result[Bool,String](Ok(True))).if_effect(left,right).get()
    except: pass
