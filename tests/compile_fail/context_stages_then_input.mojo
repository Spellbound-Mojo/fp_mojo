# error: no matching method in call to 'then'
from fp.functions import pipeline
def wrong(var value: String) -> Int: return len(value)
def main(): _ = pipeline(1).then(wrong).get()
