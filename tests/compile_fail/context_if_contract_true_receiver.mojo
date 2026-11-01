# error: invalid call to 'checked_forward': violated constraint
# error: constraint declared here evaluated to False
from context_if_contract_support import checked_forward, Missing, Once
from fp.algebra import OptionalFamily

def main():
    _ = checked_forward[OptionalFamily](Missing(),Once[OptionalFamily](2),Optional(True))
