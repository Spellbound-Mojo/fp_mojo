# error: invalid call to 'forward': violated constraint
# error: constraint declared here evaluated to False
from context_find_contract_support import forward, Even, WrongPayload, Once, OwnedPredicate
from context_find_map_contract_support import Owned
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from std.memory import ArcPointer

def main():
    _ = forward[ResultFamily[Int]](Even[ResultFamily[String]](), List[Int]([1]))
