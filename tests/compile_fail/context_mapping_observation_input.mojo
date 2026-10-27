# error: no matching method in call to 'tap_err'
"""Native observers must borrow the selected stored-error type."""
from fp.functions import pipeline
from fp.data import Result,Err
from error_mapping_support import Probe

def wrong(error:Int)->Int:return error

def main():
    _=pipeline[Probe[String]](Result[Int,String](Err(String("stored")))).tap_err(wrong)
