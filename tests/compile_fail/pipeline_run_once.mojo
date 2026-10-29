# error: no matching
from fp.functions import pipeline
from fp.effects import State
from context_state_run_support import Once
def main():
    _ = pipeline(State[Int].collect(Once(), List[Int]([1]))).run(0)
