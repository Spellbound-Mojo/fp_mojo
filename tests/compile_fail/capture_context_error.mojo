# error: no matching method in call to 'run'
from fp.data import Capture

def wrong(var value: Int) raises String -> Int: raise "wrong error"
def main():
    var capture = Capture[Int]()
    _ = capture.args(1).run(wrong)
