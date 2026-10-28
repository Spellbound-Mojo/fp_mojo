# error: thunk implements no receiver mode
from fp.callables import ThunkContract
from fp.data import attempt_once
struct Bare(ThunkContract, Movable):
    comptime Out = Int
    def __init__(out self): pass
def main():
    _ = attempt_once(Bare())
