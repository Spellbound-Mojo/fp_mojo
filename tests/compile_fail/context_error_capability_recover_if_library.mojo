# error: no matching method in call to 'recover_if'
"""Error mapping alone does not authorize selected recover_if."""
from fp.functions import pipeline
from fp.data import Result, Err
from error_mapping_support import Probe
from context_error_capability_support import Predicate, Value

def main():
    _ = pipeline[Probe[String]](Result[Int,String](Err(String("old")))).recover_if(Predicate[String](), Value[String]())
