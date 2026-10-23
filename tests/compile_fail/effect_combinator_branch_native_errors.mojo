# error: incompatible native errors
from fp.data import Result, Ok
def left() raises String -> Result[Int,String]: raise String("left")
def right() raises Int -> Result[Int,String]: raise 2
def main():
    try: _ = Result[Bool,String](Ok(True)).if_effect(left,right)
    except: pass
