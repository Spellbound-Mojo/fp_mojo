# error: invalid call to 'checked_both': violated constraint
# error: constraint declared here evaluated to False
from context_mapping_receiver_support import checked_both
from context_outcome_receiver_support import MissingUnary
from context_error_mapping_support import Show, Size
from fp.algebra import ResultFamily

def main():
    _ = checked_both[ResultFamily[String]](ResultFamily[String].pure(3),Show(),MissingUnary[String,Int]())
