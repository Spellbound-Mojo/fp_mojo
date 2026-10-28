# error: no matching method in call to 'run'
from fp.data import Capture

def wrong(a: String, mut b: String, c: Int) -> Int: return c

def main():
    var a = String("a")
    var b = String("b")
    _ = Capture().borrow(a).mutable(b).take(String("c")).run(wrong)
