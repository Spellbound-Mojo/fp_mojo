# error: no matching function
from fp.control import while_loop
def predicate(x: Int) -> Int: return x
def body(var x: Int) -> Int: return x + 1
def main():
    _ = while_loop(predicate, body, 0)
