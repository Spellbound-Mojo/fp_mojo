# error: invalid call to 'checked_flat_tap': violated constraint
# error: constraint declared here evaluated to False
from context_sequencing_receiver_support import checked_flat_tap, MissingBorrow
from fp.algebra import OptionalFamily

def main():
    _ = checked_flat_tap[OptionalFamily](Optional(3), MissingBorrow())
