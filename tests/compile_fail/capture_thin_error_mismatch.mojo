# error: no matching
from fp.data import Capture
def failing() raises Int -> Int: raise 1
def main():
    _ = Capture[String]().run(failing)
