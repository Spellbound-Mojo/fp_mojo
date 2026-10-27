# error: invalid call to 'checked_bind': violated constraint
# error: constraint declared here evaluated to False
from context_operation_receiver_support import checked_bind, MissingMap, MissingBind, MissingBinary, MissingThunk, Add, Next
from fp.algebra import OptionalFamily

def main():
    _ = checked_bind[OptionalFamily](Optional(3),MissingBind())
