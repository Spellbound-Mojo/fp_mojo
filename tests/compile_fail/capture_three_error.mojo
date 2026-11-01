# error: no matching method in call to 'run'
from fp.data import Capture

def wrong(a: String, mut b: String, var c: String) raises String -> Int: raise c^

def main():
    var a = String("a")
    var b = String("b")
    _ = Capture[Int]().borrow(a).mutable(b).take(String("c")).run(wrong)
