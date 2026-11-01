# error: no matching method in call to 'run'
from fp.data import Capture

def scaled(value: Int, *, scale: Int) -> Int: return value * scale

def main(): _ = Capture.args(3).kwargs(scale=2).run(scaled)
