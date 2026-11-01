"""Select values once; each transformation keeps the native dictionary."""
from fp.functions import pipeline_values

def text(var value: Int) -> String: return String(value)
def length(var value: String) -> Int: return value.byte_length()
def main() raises:
    var scores = Dict[String, Int]()
    scores["Ada"] = 42
    scores["Mo"] = 7
    var lengths = pipeline_values(scores^).map(text).map(length).get()
    print("lengths:", lengths["Ada"], lengths["Mo"])
