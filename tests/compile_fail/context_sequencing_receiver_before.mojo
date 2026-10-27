# error: invalid call to 'checked_before': violated constraint
# error: constraint declared here evaluated to False
from context_sequencing_receiver_support import checked_before, MissingThunk
from fp.algebra import OptionalFamily

def main():
    _ = checked_before[OptionalFamily](Optional(3), MissingThunk())
