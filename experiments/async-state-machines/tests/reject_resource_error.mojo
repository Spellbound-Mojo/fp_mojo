# error: no matching method in call to 'use'
from fp.effects._async.resources import resource
from fp.effects._async.composition import Pure, pure

def release(value: Int) -> Pure[NoneType, Int]:
    var unit: NoneType = None
    return pure[Int](unit)
def wrong(value: Int) raises String -> Pure[Int, Int]:
    raise String("foreign error")
def main():
    _ = resource(pure[Int](1), release).use(wrong)
