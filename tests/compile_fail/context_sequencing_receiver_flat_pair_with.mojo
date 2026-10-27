# error: invalid call to 'checked_flat_pair_with': violated constraint
# error: constraint declared here evaluated to False
from context_sequencing_receiver_support import checked_flat_pair_with, MissingBorrow
from fp.algebra import OptionalFamily

def main():
    _ = checked_flat_pair_with[OptionalFamily](Optional(3), MissingBorrow())
