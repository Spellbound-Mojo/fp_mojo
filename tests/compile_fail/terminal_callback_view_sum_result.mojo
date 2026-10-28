# error: no matching method
from fp.functions import partial, piped
def positive(offset: Int, value: Int) -> Bool: return value > offset
def main():
    var project = partial(positive, 1)
    _ = piped(List[Int]([1, 2])).sum_by(project).get()
