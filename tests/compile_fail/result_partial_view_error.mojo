# error: cannot call function that may raise
from fp.functions import partial
from fp.data import err

def fail(offset: Int, value: Int) raises Int -> Bool: raise offset + value
def main():
    var observer = partial(fail, 2)
    _ = err[String](1).tap_err(observer)
