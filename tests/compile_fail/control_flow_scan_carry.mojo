# error: no matching function
from fp.control import scan
def body(var x: Int, var y: Int) -> Tuple[String, Int]: return (String('changed'), y)
def main() raises:
    _ = scan(body, 0, iter(range(3)))
