# error: use of uninitialized value
from fp.data import Capture
from attempt_once_support import Consume


def main():
    var callback = Consume(2, 3)
    _ = Capture().run(callback^)
    _ = Capture().run(callback^)
