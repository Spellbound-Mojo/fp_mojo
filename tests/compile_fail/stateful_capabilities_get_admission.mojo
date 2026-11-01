# error: constraint
from fp.effects import Stateful, State, get
def read[C: Stateful]() raises C.GetError -> C.Got:
    return get[C]()
def main(): _ = read[State[Int]]()
