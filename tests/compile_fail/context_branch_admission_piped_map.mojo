# error: no matching method in call to 'map'
from fp.functions import pipeline
from context_branch_admission_support import OnceMap

def main():
    _=pipeline(List[Int]([1,2])).map(OnceMap()).get()
