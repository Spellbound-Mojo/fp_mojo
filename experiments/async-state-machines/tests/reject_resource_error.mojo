# error: no matching method in call to 'use'
from fp.effects._async.engine import IO
from fp.effects._async.io_resource import Resource

def release(value: Int) -> IO[NoneType, Int]:
    return IO[NoneType, Int].pure(NoneType())
def wrong(value: Int) raises String -> IO[Int, Int]:
    raise String("foreign error")
def main():
    _ = Resource[Int, Int].make(IO[Int, Int].pure(1), release).use(wrong)
