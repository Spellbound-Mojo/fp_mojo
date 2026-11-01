# error: no matching method in call to 'run'
from fp.data import Capture

def defaults(first: Int, second: Int = 3) -> Int: return first * 10 + second

def main(): _ = Capture.args(2).run(defaults)
