# error: no matching method
from fp.functions import pipeline
def callback(value: Int) -> Bool: return True
def main(): _ = pipeline(List[String](["value"])).filter_not(callback).get()
