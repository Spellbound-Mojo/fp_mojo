# error: invalid call to 'some': violated constraint
# error: constraint declared here evaluated to False
from context_boolean_contract_support import some, every
from context_find_contract_support import Even, WrongPayload, Once, OwnedPredicate
from context_find_map_contract_support import Owned
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from std.memory import ArcPointer

def main():
    _ = some[ResultFamily[Int]](Even[ResultFamily[String]](), List[Int]([1]))
