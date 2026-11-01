from fp.callables import BorrowSignature
from fp.effects._async.engine import IO
from fp.effects._async.io_resource import Resource
from fp.effects._async.kernel import run
from foundation import check

def release(value: Int) raises Int -> IO[NoneType, Int]:
    # A factory failure is captured under the same cleanup ownership as the
    # IO it could have returned.
    raise value + 1

def body(value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value * 2)

def main():
    var factory = BorrowSignature[Int, IO[NoneType, Int], Int].capture(release)
    var outcome = run(Resource[Int, Int].make(IO[Int, Int].pure(7), factory^).use(body))
    var failure = outcome.take()._take_err()
    check(not failure.canceled and len(failure.errors) == 1 and failure.errors.first() == 8, "native release factory error remains cleanup failure")
    print("resource factory: native borrowed release, captured cleanup factory error")
