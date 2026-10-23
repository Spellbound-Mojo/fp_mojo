# error: no matching method in call to 'filter_not'
from fp.functions import piped

def select(var x: Int) -> Bool: return x > 0
def main():
    var xs: List[Int] = [1, 2]
    _ = piped(xs^).filter_not(select).get()
