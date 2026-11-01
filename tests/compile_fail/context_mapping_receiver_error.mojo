# error: invalid call to 'checked_error': violated constraint
# error: constraint declared here evaluated to False
from context_mapping_receiver_support import checked_error
from context_outcome_receiver_support import MissingUnary
from context_error_mapping_support import Show, Size
from fp.algebra import ResultFamily

def main():
    _ = checked_error[ResultFamily[String]](ResultFamily[String].pure(3),MissingUnary[String,Int]())
