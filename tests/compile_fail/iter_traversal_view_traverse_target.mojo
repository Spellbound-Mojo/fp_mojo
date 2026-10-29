# error: no matching method in call to 'traverse'
from fp.functions import kleisli, flow
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
def callback(var value: Int) -> Optional[Int]: return None
def main():
    var chain = kleisli[OptionalFamily](callback)
    _ = iterated(range(2)).traverse[ResultFamily[String]](chain)
