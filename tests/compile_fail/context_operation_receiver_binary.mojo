# error: invalid call to 'checked_combine': violated constraint
# error: constraint declared here evaluated to False
from context_operation_receiver_support import checked_combine, MissingMap, MissingBind, MissingBinary, MissingThunk, Add, Next
from fp.algebra import OptionalFamily

def main():
    _ = checked_combine[OptionalFamily](Optional(3),MissingBinary(),Next())
