# error: has no attribute 'take'
from fp.data import Capture

def main():
    var a = String("a")
    var b = String("b")
    _ = Capture().borrow(a).mutable(b).take(String("c")).take(String("fourth"))
