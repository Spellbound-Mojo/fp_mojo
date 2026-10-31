# error: cannot call function that may raise
from fp.functions import partial, pipeline

def fail(offset: Int, value: Int) raises Int -> Bool: raise offset + value
def main():
    var predicate = partial(fail, 2)
    _ = pipeline(List[Int]([1])).filter(predicate).get()
