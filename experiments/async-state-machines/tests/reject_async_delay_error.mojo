# error: no matching function
from fp.effects._async.io import delay
def wrong() raises String -> Int:
    raise String("wrong native error")
def main():
    _ = delay[Int](wrong)
