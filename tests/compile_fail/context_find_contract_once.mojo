# error: invalid call to 'forward'
# error: argument type 'Once' does not conform to trait 'BorrowCallable'
from context_find_contract_support import forward, Even, WrongPayload, Once, OwnedPredicate
from context_find_map_contract_support import Owned
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from std.memory import ArcPointer

def main():
    _ = forward[OptionalFamily](Once(), List[Int]([1]))
