# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, Monoid
struct Text(Monoid):
    comptime Value = String
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> String: return String()
    @staticmethod
    def combine(var a: String, var b: String) raises Int -> String: return a + b
def callback(var value: Int) raises String -> Optional[String]: raise String("other error")
def main(): _ = pipeline(List[Int]([1])).raising[String]().fold_map_effect[Text](callback).get()
