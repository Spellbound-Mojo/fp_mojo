# error: no matching method in call to 'flat_tap_err'
from fp.algebra import ValidationFamily, Semigroup
from fp.data import Result, Err
from fp.functions import pipeline

struct ObservationErrors(Semigroup):
    comptime Value = String
    comptime Error = Int
    @staticmethod
    def combine(var left: String, var right: String) raises Int -> String:
        raise 1

def inspect(error: String) raises String -> Result[Int, String]:
    return Err(String("observer"))

def main() raises:
    _ = pipeline[ValidationFamily[ObservationErrors]](Result[Int, String](Err(String("original")))).flat_tap_err(inspect).get()
