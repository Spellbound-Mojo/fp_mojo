# error: has no attribute
from fp.data import Capture
def main():
    _ = Capture[Never].args(1,2,3).kwargs(extra=4)
