# error: invalid call to 'forward': violated constraint
# error: constraint declared here evaluated to False
from context_if_contract_support import forward, Factory, Once, StringFactory, ErrorFactory, PointerFactory
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from fp.data import Result, Ok

def main():
    _ = forward[ListFamily](Once[ListFamily](1), Once[ListFamily](2), List[Bool]([True,False]))
