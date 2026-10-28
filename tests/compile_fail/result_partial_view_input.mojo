# error: no matching method
from fp.functions import partial
from fp.data import err

def long(limit: Int, value: String) -> Bool: return value.byte_length() > limit
def main():
    var observer = partial(long, 2)
    _ = err[String](1).tap_err(observer)
