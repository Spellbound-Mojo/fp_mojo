# error: no matching method in call to 'filter_not'
from fp.functions import piped

def select(x: Int) -> Int: return x
def main():
    var xs: List[Int] = [1, 2]
    _ = piped(xs^).filter_not(select).get()
