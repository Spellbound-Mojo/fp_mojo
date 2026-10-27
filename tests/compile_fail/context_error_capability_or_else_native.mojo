# error: no matching method in call to 'or_else'
"""Error mapping alone does not authorize selected or_else."""
from fp.functions import pipeline
from fp.data import Result, Err
from error_mapping_support import Probe
from context_error_capability_support import effect

def main():
    _ = pipeline[Probe[String]](Result[Int,String](Err(String("old")))).or_else(effect)
