from fp.effects._async.resources import resource
from fp.effects._async.composition import Pure, pure
from fp.effects._async.kernel import run
from foundation import check

def release(value: Int) raises Int -> Pure[NoneType, Int]:
    # A factory failure is captured under the same cleanup ownership as the
    # machine it could have returned.
    raise value + 1

def body(value: Int) -> Pure[Int, Int]:
    return pure[Int](value * 2)

def main():
    var outcome = run(resource(pure[Int](7), release).use(body))
    var failure = outcome.take()._take_err()
    check(not failure.canceled and len(failure.errors) == 1 and failure.errors.first() == 8, "native release factory error remains cleanup failure")
    print("resource factory: native borrowed release, captured cleanup factory error")
