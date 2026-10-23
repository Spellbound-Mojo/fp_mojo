# error: constructor Both has no clause that cannot decline
import fp
from fp.data import Ior, Left, Right, Both
def main():
    var value: Ior[String, Int] = Both(String("warning"), 1)
    _ = fp.match(value,
        lambda (left: Left[String]) -> Int: 0,
        lambda (right: Right[Int]) -> Int: right.value)
