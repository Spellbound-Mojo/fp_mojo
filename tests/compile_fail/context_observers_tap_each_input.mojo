# error: no matching method
from fp.functions import pipeline
def callback(value: Int) -> Int: return 1
def main(): _ = pipeline(List[String](["value"])).tap_each(callback).get()
