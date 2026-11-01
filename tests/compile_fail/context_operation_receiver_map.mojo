# error: invalid call to 'checked_map': violated constraint
# error: constraint declared here evaluated to False
from context_operation_receiver_support import checked_map, MissingMap, MissingBind, MissingBinary, MissingThunk, Add, Next
from fp.algebra import OptionalFamily

def main():
    _ = checked_map[OptionalFamily](Optional(3),MissingMap())
