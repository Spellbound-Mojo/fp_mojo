# error: no matching method in call to 'filter'
from fp.functions import piped

def select(x: Int) -> Int: return x
def main():
    var xs: List[Int] = [1, 2]
    _ = piped(xs^).filter(select).get()
