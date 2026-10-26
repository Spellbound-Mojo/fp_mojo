# error: no matching method
from fp.functions import pipeline
def callback() -> Int: return 1
def main(): _ = pipeline(String("value")).tap(callback).get()
