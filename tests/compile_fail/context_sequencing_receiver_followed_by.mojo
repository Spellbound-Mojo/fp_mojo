# error: invalid call to 'checked_followed_by': violated constraint
# error: constraint declared here evaluated to False
from context_sequencing_receiver_support import checked_followed_by, MissingThunk
from fp.algebra import OptionalFamily

def main():
    _ = checked_followed_by[OptionalFamily](Optional(3), MissingThunk())
