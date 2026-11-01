# error: no matching method in call to 'then'
from fp.functions import pipeline
@fieldwise_init
struct Fault(Movable):
    var code: Int
def wrong(var value: Int) raises Fault -> Int: raise Fault(value)
def main() raises: _ = pipeline(1).raising[String]().then(wrong).get()
