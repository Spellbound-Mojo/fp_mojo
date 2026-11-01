# error: no matching method
from fp.functions import pipeline
def callback(var value: String) -> Bool: return True
def main():
    var pointer: def(var String) thin -> Bool = callback
    _ = pipeline(List[String](["value"])).tap_each(pointer).get()
