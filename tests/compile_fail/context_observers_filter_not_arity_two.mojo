# error: no matching method
from fp.functions import pipeline
def callback(first: String, second: String) -> Bool: return True
def main(): _ = pipeline(List[String](["value"])).filter_not(callback).get()
