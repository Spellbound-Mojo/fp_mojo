# error: use of uninitialized value
from fp.data import attempt_once
from attempt_once_support import Consume


def main():
    var callback = Consume(2, 3)
    _ = attempt_once(callback^)
    _ = attempt_once(callback^)
