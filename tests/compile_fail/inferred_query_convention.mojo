# error: no matching
from fp.functions import pipeline
def callback(var value: String) -> Optional[Bool]: return Optional(True)
def main() raises:
    var pointer: def(var String) thin -> Optional[Bool] = callback
    _ = pipeline(List[String](["one"])).any_effect(pointer)
