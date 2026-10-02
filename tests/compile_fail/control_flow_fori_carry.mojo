# error: no matching function
from fp.control import fori_loop
def body(var index: Int, var x: Int) -> String: return String('wrong carry')
def main():
    _ = fori_loop(0, 3, body, 0)
