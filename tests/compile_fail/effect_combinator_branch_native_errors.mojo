from fp.functions import pipeline
# The branches raise String and Int; no common native error exists.
# error: no matching method in call to 'if_effect'
from fp.data import Result, Ok
def left() raises String -> Result[Int,String]: raise String("left")
def right() raises Int -> Result[Int,String]: raise 2
def main():
    try: _ = pipeline(Result[Bool,String](Ok(True))).if_effect(left,right).get()
    except: pass
