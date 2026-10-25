# error: no matching function
# A native callback must be admitted on an already constructed context.
from fp.data import Capture

def callback() -> Int: return 1
def main():
    _ = Capture.run(callback)
