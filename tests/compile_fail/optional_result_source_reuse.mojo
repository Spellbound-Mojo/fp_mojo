# error: use of uninitialized value
from fp.functions import pipeline
def factory() -> String: return String("missing")
def main():
    var source = Optional(String("value"))
    _ = pipeline(source^).to_result(factory)
    _ = source^
