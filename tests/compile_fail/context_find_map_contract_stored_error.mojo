# error: invalid call to 'forward': violated constraint
# error: constraint declared here evaluated to False
from context_find_map_contract_support import forward, Text, WrongPayload, OnceText, Owned, OwnedQuery
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from std.memory import ArcPointer

def main():
    _ = forward[ResultFamily[Int]](Text[ResultFamily[String]](), List[Int]([1]))
