# error: no matching method in call to 'ensure'
"""Error mapping alone does not authorize selected ensure."""
from fp.functions import pipeline
from fp.data import Result, Err
from error_mapping_support import Probe
from context_error_capability_support import Predicate, MakeError

def main():
    _ = pipeline[Probe[String]](Result[Int,String](Err(String("old")))).ensure(Predicate[Int](), MakeError())
