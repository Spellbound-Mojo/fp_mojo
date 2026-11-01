# error: no matching method in call to 'run'
from fp.data import Capture

def wrong(a: String, mut b: String, var c: String, /, var **options: Int) -> Int: return 1

def main():
    var a = String("a")
    var b = String("b")
    _ = Capture().borrow(a).mutable(b).take(String("c")).kwargs(extra=String("bad")).run(wrong)
