# error: no matching method in call to 'tap_err'
"""An admitted different default target cannot replace the selected family."""
from fp.functions import pipeline
from fp.data import Result,Err
from context_error_mapping_nonmonad_support import ToValidation
from context_error_capability_support import observe

def main():
    _=pipeline[ToValidation](Result[Int,String](Err(String("stored")))).tap_err(observe)
