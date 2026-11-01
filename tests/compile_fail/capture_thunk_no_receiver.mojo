# error: thunk implements no receiver mode
from fp.callables import ThunkContract
from fp.data import Capture
struct Bare(ThunkContract, Movable):
    comptime Out = Int
    def __init__(out self): pass
def main():
    _ = Capture[String]().run(Bare())
