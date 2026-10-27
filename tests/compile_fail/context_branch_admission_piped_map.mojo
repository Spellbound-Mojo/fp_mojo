# error: no matching method in call to 'map'
from fp.functions import piped
from context_branch_admission_support import OnceMap

def main():
    _=piped(List[Int]([1,2])).map(OnceMap()).get()
