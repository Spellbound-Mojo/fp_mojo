# error: no matching method
from fp.functions import partial
from fp.data import err, ok, Result

def changed(offset: Int, value: Int) -> Result[Int, String]: return ok[String](offset + value)
def main():
    var observer = partial(changed, 2)
    _ = err[String](1).flat_tap_err(observer)
