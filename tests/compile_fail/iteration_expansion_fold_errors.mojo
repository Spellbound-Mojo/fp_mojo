# error: no matching method in call to 'collect_fold'
from fp.iteration import iterated
from fp.algebra import Monoid
@fieldwise_init
struct I12CallbackError(Movable):
    var code: Int
@fieldwise_init
struct I12MonoidError(Movable):
    var code: Int
struct I12Monoid(Monoid):
    comptime Value = String
    comptime Error = I12MonoidError
    @staticmethod
    def empty() raises Self.Error -> String: return String()
    @staticmethod
    def combine(var a: String,var b: String) raises Self.Error -> String: return a+b
def select(var value: Int) raises I12CallbackError -> Optional[String]: return Optional(String(value))
def main() raises: _ = iterated(range(3)).collect_fold[M=I12Monoid](select)
